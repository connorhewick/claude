# Swift Concurrency Patterns

Write Swift concurrent code (Swift 5.9+, iOS 17 era) that the compiler can prove
data-race-free, that cancels cleanly, and that keeps the main thread responsive — not code
that merely "works in testing."

## Overview

Swift concurrency replaces the GCD/locks era with a model the compiler enforces: `async/await`
for suspension, actors for isolated mutable state, `Sendable` for what may cross isolation
boundaries, and a task tree for lifetime and cancellation. The core philosophy: **make the
compiler prove safety instead of hoping reviewers spot races.** Every queue you would have
reached for in GCD has a structured equivalent that is also cancellable and priority-aware.
Prefer the structured form; reach for unstructured `Task {}` and locks only at well-justified
boundaries.

## Core Concepts

### The task tree, not fire-and-forget

Structured concurrency means every child task lives inside its parent's scope: `async let` and
task groups cannot outlive the function that created them. This is the concurrency analogue of
RAII — when the parent returns or throws, children are awaited or cancelled, so you cannot leak
work. Unstructured `Task {}` opts out of this tree: it inherits actor context and priority but
nobody awaits it, nobody cancels it, and errors vanish. Use it only at the boundary between
synchronous and async worlds (e.g., a button action), and store the handle if you ever need to
cancel it.

### `await` marks a suspension point — and a state hazard

At every `await`, your function may pause, and the world may change before it resumes:
other code runs on the same actor, properties you checked may now be stale. This is the root of
re-entrancy bugs. Mental model: **everything you verified before an `await` is unverified after
it.** Re-check invariants after resuming, or restructure so the check and the mutation have no
`await` between them.

### Actors serialize access, they don't freeze state

An actor guarantees only one task touches its mutable state *at a time* — but actors are
re-entrant: while one method is suspended at an `await`, another call can interleave. Actors
prevent data races (torn reads/writes), not logic races (check-then-act across suspension).
Design actor methods to be transactional: do all reads, awaits, then writes, or guard with an
in-flight flag/task cache.

### `Sendable` is the passport for crossing isolation

`Sendable` means "safe to copy across concurrency domains": value types of Sendable parts,
final classes with immutable state, or `@unchecked Sendable` types that protect themselves
(e.g., with a lock). Under strict concurrency checking (`SWIFT_STRICT_CONCURRENCY=complete`,
the Swift 6 default), every captured value crossing a boundary must be Sendable. Don't silence
warnings with `@unchecked Sendable` unless the type genuinely synchronizes internally — that
annotation is a promise to the compiler that *you* now keep manually.

### `@MainActor` is a type-system fact, not a runtime hope

UI state belongs on the main actor, declared with `@MainActor` on the type or member, so the
compiler — not `DispatchQueue.main.async` sprinkled defensively — guarantees main-thread
access. Annotate whole ObservableObject/`@Observable` view models `@MainActor` rather than
individual methods; partial annotation creates hop churn and confusing isolation mismatches.

### Cancellation is cooperative

Cancelling a task sets a flag; nothing stops unless the code checks. Built-in awaits
(`URLSession`, `Task.sleep`) check for you; your loops and CPU-bound work must call
`try Task.checkCancellation()` or read `Task.isCancelled`. A task that ignores cancellation
holds resources, burns battery, and delays UI teardown.

## Decision Framework

| Situation | Use | Why |
|---|---|---|
| Mutable state shared across tasks, callers can be async | `actor` | Compiler-proven isolation, async-friendly, re-entrant under suspension |
| Hot synchronous state, called from sync code, no awaits inside | Lock (`OSAllocatedUnfairLock`/`Mutex`) | Actors force `await` on callers; locks are sync and cheaper for tiny critical sections |
| State that drives UI | `@MainActor` type | UI is already a serialization domain; a second actor just adds hops |
| Fixed small number of concurrent child results | `async let` | Lightest structured form, reads top-to-bottom |
| Dynamic number of concurrent operations | `withThrowingTaskGroup` | Bounded by scope, supports streaming results and cancellation |
| Bridging sync context (button tap, delegate) into async | `Task {}` (store handle if cancellable) | The one legitimate unstructured entry point |
| Work must outlive view/object, independent priority | `Task.detached` — rare | Loses actor context and priority inheritance; justify in a comment |
| Stream of values over time (events, sockets) | `AsyncStream`/`AsyncSequence` | Native backpressure via pull; prefer over Combine for new code |
| Existing Combine pipelines, UIKit bindings | Keep Combine, bridge with `.values` | Rewriting working pipelines is churn, not progress |

Rule of thumb for actors vs locks: if the critical section contains an `await` or callers are
async, actor. If it's a few nanoseconds of synchronous mutation called from sync code, lock.
Never hold a lock across an `await` — that is the worst of both worlds and can deadlock.

## Workflow

1. **Read the existing code.** Identify current isolation: GCD queues, locks, `@MainActor`
   annotations, Combine pipelines, and the project's `SWIFT_STRICT_CONCURRENCY` level. Map
   which state is shared and who mutates it.
2. **Classify each piece of shared state**: UI-driving → `@MainActor`; shared model/cache →
   actor; immutable → `let` + `Sendable`; sync hot path → lock.
3. **Design the task topology** before writing code: what is structured (`async let`, group)
   vs. the few unstructured entry points, and where cancellation must propagate.
4. **Annotate isolation at the type level** (`@MainActor` on the view model, `actor` on the
   cache), not call sites. Let the compiler surface every boundary crossing.
5. **Make crossing types `Sendable`** — prefer structs and immutable final classes; use
   `@unchecked Sendable` only with internal synchronization and a comment explaining it.
6. **Add cancellation checks** in loops and long CPU work; ensure `Task` handles owned by
   objects are cancelled in `deinit`/`onDisappear`.
7. **Audit every `await` inside actors** for check-then-act re-entrancy; restructure or add
   in-flight task caching.
8. **Verify**: build with strict concurrency complete (zero warnings), run with Thread
   Sanitizer, test cancellation paths explicitly, then run the Quality Checklist below.

## Patterns

### Actor with re-entrancy-safe caching

The in-flight `Task` is stored *before* the first `await`, so concurrent callers join the same
fetch instead of racing past a stale check:

```swift
actor ImageCache {
    private var cache: [URL: UIImage] = [:]
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache[url] { return cached }
        if let task = inFlight[url] { return try await task.value }

        let task = Task { try await Self.fetch(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let image = try await task.value
        cache[url] = image
        return image
    }
}
```

### MainActor view model with structured loading

```swift
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: LoadState<Profile> = .idle
    private var loadTask: Task<Void, Never>?

    func load(id: Profile.ID, api: any ProfileAPI) {
        loadTask?.cancel()
        loadTask = Task {
            state = .loading
            do {
                state = .loaded(try await api.profile(id: id))
            } catch is CancellationError {
                // superseded by a newer load — leave state alone
            } catch {
                state = .failed(error)
            }
        }
    }
}
```

### Task group with bounded concurrency

Cap in-flight work by seeding `maxConcurrent` children and adding one as each finishes —
groups stream results; they don't have to fan out everything at once:

```swift
func thumbnails(for urls: [URL], maxConcurrent: Int = 4) async throws -> [URL: UIImage] {
    try await withThrowingTaskGroup(of: (URL, UIImage).self) { group in
        var results: [URL: UIImage] = [:]
        var iterator = urls.makeIterator()

        for _ in 0..<maxConcurrent {
            guard let url = iterator.next() else { break }
            group.addTask { (url, try await fetchThumbnail(url)) }
        }
        while let (url, image) = try await group.next() {
            results[url] = image
            if let next = iterator.next() {
                group.addTask { (next, try await fetchThumbnail(next)) }
            }
        }
        return results
    }
}
```

### Cooperative cancellation in CPU-bound work

```swift
func index(_ documents: [Document]) async throws -> SearchIndex {
    var index = SearchIndex()
    for (i, doc) in documents.enumerated() {
        if i.isMultiple(of: 64) { try Task.checkCancellation() }
        index.add(doc)
    }
    return index
}
```

### Bridging a callback API with AsyncStream

```swift
func locations() -> AsyncStream<CLLocation> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let delegate = LocationDelegate { continuation.yield($0) }
        manager.delegate = delegate
        manager.startUpdatingLocation()
        continuation.onTermination = { _ in manager.stopUpdatingLocation() }
    }
}
```

`bufferingNewest(1)` is the backpressure decision: for state-like streams (location, progress),
drop stale values; for event-like streams (taps, messages), use `.unbounded` deliberately.

### Sendable conformance done honestly

```swift
struct UploadRequest: Sendable {          // value type of Sendable parts — free
    let url: URL
    let payload: Data
}

final class Counter: @unchecked Sendable { // promise kept by an internal lock
    private let lock = OSAllocatedUnfairLock(initialState: 0)
    func increment() -> Int { lock.withLock { $0 += 1; return $0 } }
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Duplicate network requests, double-applied state changes | Actor re-entrancy: invariant checked before `await`, acted on after | Cache the in-flight `Task` before first suspension; re-check state after every `await` |
| Work continues after screen dismissed; battery drain | Unstructured `Task {}` never cancelled | Store the handle; cancel in `deinit`/`onDisappear`; or use SwiftUI `.task {}` which auto-cancels |
| UI updates crash or warn off main thread | Hoping callbacks arrive on main instead of declaring it | `@MainActor` on the whole view model type; delete defensive `DispatchQueue.main.async` |
| Deadlock or priority inversion under load | Holding a lock (or semaphore-waiting) across an `await` | Never block in async code; convert the section to an actor or move the await outside the lock |
| `Task.detached` everywhere "for background work" | Misunderstanding: `await` already doesn't block the caller | Use plain `Task {}` or structured children; detach only to escape actor context deliberately |
| Cancellation "doesn't work" | CPU-bound loop never checks the flag | `try Task.checkCancellation()` periodically; check `Task.isCancelled` before expensive steps |
| Hundreds of Sendable warnings on enabling strict mode | Non-Sendable classes captured across boundaries | Fix the types (structs, immutable finals, actors) — don't blanket `@unchecked Sendable` |
| Sluggish app, main thread busy | Heavy synchronous work in a `@MainActor` context — `async` does not mean "off main" | Move computation into a nonisolated/detached function or an actor; await its result on main |
| Stale result overwrites fresh one | Two loads race; the slower finishes last | Cancel the previous task before starting a new one (see view model pattern) and ignore `CancellationError` |

## Quality Checklist

- [ ] No `await` inside an actor method between checking an invariant and acting on it (or an in-flight task cache makes the race harmless)
- [ ] Builds clean with strict concurrency checking set to `complete`
- [ ] Every unstructured `Task {}` has an owner that cancels it, or is provably fire-safe (e.g., SwiftUI `.task`)
- [ ] No locks or semaphores held across `await`; no `DispatchSemaphore.wait` in async code
- [ ] UI-mutating types are `@MainActor` at the type level; no defensive `DispatchQueue.main.async` remains
- [ ] Long loops and CPU-bound work check cancellation; cancellation paths are tested
- [ ] `@unchecked Sendable` appears only with internal synchronization and an explanatory comment
- [ ] Concurrent fan-out uses `async let` or task groups, with concurrency bounded where input size is unbounded
- [ ] Superseded loads are cancelled and `CancellationError` is handled distinctly from real failures
- [ ] `Task.detached` usages are justified in a comment (escaping actor context on purpose)
- [ ] AsyncStream buffering policy chosen deliberately (newest-N for state, unbounded only for must-not-drop events)
- [ ] Thread Sanitizer run on the touched paths with no findings
