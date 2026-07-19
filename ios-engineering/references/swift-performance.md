# Swift Performance Optimization

Make iOS apps measurably faster and leaner — emphasis on *measurably*: every optimization
starts with a profile and ends with a number that proves it worked.

## Overview

Performance work fails in two predictable ways: optimizing without measuring (you "fix" code
that was never hot), and measuring the wrong thing (Debug builds, simulator, averages instead
of worst frames). The core philosophy: **profile a Release build on a real, older device,
find the top item in the profile, fix only that, re-measure.** Most iOS performance problems
are not exotic — they're main-thread blocking, allocation churn in loops, oversized images,
and accidental O(n²) — and Instruments points straight at them if you let it.

## Core Concepts

### Measure first, on the right build

Debug builds disable optimizations (`-Onone`), add exclusivity checks, and can be 10–100×
slower in tight Swift code — a Debug profile will send you chasing ghosts. Profile Release
(or the Profile scheme action, which defaults to Release) on the oldest device you support.
Capture a baseline number before touching anything; without it you cannot prove the fix or
detect the regression.

### The frame budget is the contract

120Hz displays give you ~8ms per frame on the main thread; 60Hz gives ~16ms. Anything on the
main thread that can exceed the budget — JSON decoding, image decode, Core Data fetches,
synchronous disk I/O — is jank waiting for a slow device. Averages lie; hitches are caused by
the *worst* frame, so look at hitch metrics and the Time Profiler's heaviest stacks during
interaction, not mean CPU.

### Structs are cheap until they're big and copied often

Value types avoid heap allocation, ARC, and sharing bugs — the right default. But a struct's
copy cost is proportional to its size, and a struct containing many class references makes
every copy retain/release each one. Standard library collections (`Array`, `String`,
`Dictionary`) solve this with copy-on-write: copies share storage until mutation. The trap is
*accidental CoW copies* — mutating an array that something else also references forces a full
buffer copy; in a loop, that's quadratic. For your own large structs, either keep them small,
make them classes when identity is the point, or implement CoW with a boxed storage class and
`isKnownUniquelyReferenced`.

### ARC traffic is a real cost in hot loops

Every class reference passed around can incur retain/release pairs — atomic operations that
dominate tight loops. You rarely see "ARC" in a profile; you see `swift_retain`/
`swift_release` near the top. Cures: prefer value types in hot paths, mark classes `final`
(enables devirtualization and lets the optimizer elide retains), hoist invariant references
out of loops, and avoid repeatedly bouncing references through closures. Don't `unowned`-hack
your way around ARC for performance until a profile names it.

### Collections: capacity, contiguity, and the right structure

Growing an `Array` element-by-element reallocates and copies repeatedly —
`reserveCapacity(_:)` when the size is known. `Dictionary`/`Set` lookups are O(1) but hashing
cost is real; `array.contains` inside a loop over another array is the classic hidden O(n²) —
build a `Set` once. `String` is not random access: `s[s.index(s.startIndex, offsetBy: i)]` in
a loop is O(n²); iterate characters or work on `UTF8View`. Existential collections
(`[any Shape]`) box elements and prevent specialization; in hot paths prefer generics or
concrete/enum types.

### Lazy sequences trade allocation for recomputation

`items.lazy.filter{...}.map{...}.first(...)` avoids building intermediate arrays and stops
early — ideal for "find first match" over large inputs. But a lazy sequence re-runs its
closures *every time it's iterated*: iterate twice, pay twice. Rule: lazy for single-pass,
early-exit pipelines; materialize with `Array(...)` for anything consumed more than once.

### Memory is mostly images and lingering object graphs

Real-world iOS footprint problems are dominated by image decoding (a 4000×3000 JPEG decodes
to ~46MB of bitmap regardless of file size — downsample with ImageIO to display size) and
object graphs kept alive by retain cycles or caches without eviction. Leaks instrument finds
cycles; Allocations with generation marking ("Mark Generation" around a repeated flow) finds
abandoned-but-reachable memory, which is more common than true leaks.

## Decision Framework

### Symptom → instrument

| Symptom | Start with |
|---|---|
| Scrolling jank, animation hitches | Time Profiler (main thread, during interaction) + Animation Hitches template |
| Slow cold launch | App Launch template; XCTest `XCTApplicationLaunchMetric` for regression |
| Memory growth / jetsam kills | Allocations with generation marking; Leaks for cycles; memgraph for who-retains-whom |
| Battery complaints | Energy Log + Network instrument (radio wake-ups dominate) |
| Slow specific operation | `os_signpost` around it + Time Profiler; `XCTMeasure` to lock in the win |
| SwiftData/Core Data slowness | Core Data instrument (fetch counts, faulting churn — applies to SwiftData's underlying store too) — see `swiftdata-schema-designer.md` |

### Optimize vs. ship

Optimize now only if: a user-visible metric misses budget (hitch rate, launch > ~500ms warm /
~2s cold, memory near jetsam limits), the profile names a clear culprit, and the fix is
contained. Otherwise ship, and add a metric (MetricKit, XCTest performance baseline) so
regressions surface instead of accumulating. "This code looks slow" is not a reason; "this
stack is 40% of the trace" is.

### struct vs class (performance lens)

Small data, value semantics natural → struct. Large/frequently copied with reference-heavy
fields → class, or CoW box. Identity/lifecycle matters (controllers, caches) → `final class`.
Polymorphism in a hot loop → generics or enums over existentials.

## Workflow

1. **Read the existing code and reproduce the complaint.** Identify the exact user scenario
   ("scroll the feed", "open the editor"), the device class it occurs on, and any existing
   performance tests or signposts.
2. **Establish a baseline**: Release build, real device, the scenario scripted or repeatable.
   Record the number (hitch rate, ms, MB) — this is the success criterion.
3. **Profile with the matching instrument** (table above). Invert the call tree, hide system
   libraries first, look at the heaviest stack during the bad moment.
4. **Form one hypothesis** from the top of the profile. Add `os_signpost` intervals if the
   hot region is ambiguous.
5. **Fix only the top item.** Apply the relevant pattern below (move off main, downsample,
   reserve capacity, kill the O(n²), break the cycle). Resist drive-by "optimizations" of
   code the profile didn't name.
6. **Re-measure the same scenario.** No improvement → revert, back to step 4. Improvement →
   record before/after.
7. **Lock it in**: add an `XCTMeasure`-based performance test or MetricKit/launch baseline so
   the win can't silently regress.
8. **Verify against the Quality Checklist** below.

## Patterns

### Signposts to make hot regions visible in Instruments

```swift
import OSLog

let signposter = OSSignposter(subsystem: "com.app.feed", category: .pointsOfInterest)

func loadFeed() async throws -> [Post] {
    let state = signposter.beginInterval("loadFeed")
    defer { signposter.endInterval("loadFeed", state) }
    return try await api.fetchPosts()
}
```

### Performance regression test

```swift
func testFeedDiffPerformance() {
    let old = PostFixtures.posts(count: 5_000)
    let new = PostFixtures.shuffled(old)
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        _ = FeedDiffer.diff(old: old, new: new)
    }
    // Set a baseline in Xcode; CI fails on regression.
}
```

### Copy-on-write for a large value type

```swift
struct Canvas {
    private final class Storage {
        var pixels: [Pixel]
        init(pixels: [Pixel]) { self.pixels = pixels }
        func copy() -> Storage { Storage(pixels: pixels) }
    }
    private var storage: Storage

    mutating func set(_ pixel: Pixel, at index: Int) {
        if !isKnownUniquelyReferenced(&storage) {   // copy only when shared
            storage = storage.copy()
        }
        storage.pixels[index] = pixel
    }
}
```

### Collection hygiene in a hot path

```swift
func visibleIDs(in posts: [Post], hidden: [Post.ID]) -> [Post.ID] {
    let hiddenSet = Set(hidden)                  // O(n) once, not O(n) per element
    var result: [Post.ID] = []
    result.reserveCapacity(posts.count)          // no incremental regrowth
    for post in posts where !hiddenSet.contains(post.id) {
        result.append(post.id)
    }
    return result
}
```

### Lazy pipeline for early exit (single pass only)

```swift
let firstFlagged = posts.lazy
    .map(enrich)                 // runs only until a match is found
    .first { $0.isFlagged }
// If the pipeline's output is needed repeatedly: let enriched = posts.map(enrich)
```

### Image downsampling instead of full decode

```swift
func downsampledImage(at url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let maxDimension = max(pointSize.width, pointSize.height) * scale
    let options = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension,
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options).map(UIImage.init)
}
```

Decodes at display size — a list of thumbnails costs kilobytes per cell instead of tens of
megabytes.

### Keeping the main thread inside the frame budget

```swift
// Heavy work computed off the main actor; only the result hops back.
func search(_ query: String) async {
    let posts = self.posts
    let matches = await Task.detached(priority: .userInitiated) {
        posts.filter { $0.matches(query) }      // pure function over Sendable input
    }.value
    self.results = matches                       // back on @MainActor
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| "Optimization" shows huge wins locally, none in production | Profiled a Debug build or the simulator | Always profile Release on the oldest supported device |
| Loop over thousands of items mysteriously quadratic | Accidental CoW copy: shared array mutated per iteration, or `Array.contains` in the loop | Ensure unique ownership before the loop; hoist membership into a `Set` |
| `swift_retain`/`swift_release` at the top of Time Profiler | Class references churned in a hot loop; non-final classes blocking optimization | Value types in the hot path; `final` classes; hoist references out of loops |
| Memory spikes when a photo screen opens | Full-resolution decode of large images into memory | ImageIO downsampling to display size; `prepareForDisplay`/`byPreparingThumbnail` on iOS 15+ |
| Lazy chain made things slower | Lazy sequence iterated multiple times, re-running closures each pass | Materialize with `Array(...)` when consumed more than once; lazy only for single-pass/early-exit |
| Hitches during scroll despite "fast" code | Synchronous decode/layout/Core Data faulting on the main thread per cell | Precompute and cache cell view-models; decode images off-main; batch fetches |
| Memory climbs forever, Leaks instrument finds nothing | Abandoned memory: caches without eviction, screens retained by closures/observers | Allocations generation marking around the flow; `[weak self]` in long-lived closures; `NSCache` or explicit eviction |
| String processing crawls on large input | Index arithmetic on `String` (O(n) per index) in a loop | Single-pass character iteration or `UTF8View`; avoid repeated `index(_:offsetBy:)` |
| Array building dominates the trace | Incremental growth reallocations or repeated `+=` on `String` in loops | `reserveCapacity`; collect then `joined()` |
| Two weeks spent micro-tuning, app feels the same | Optimizing code the profile never named | Top-of-profile rule: fix only the heaviest stack, re-measure, repeat |

## Quality Checklist

- [ ] A baseline measurement (Release, real device, defined scenario) exists from *before* the change, and the after-number beats it
- [ ] The optimization targets the top of an actual profile, not a hunch
- [ ] Main thread does no synchronous I/O, JSON decoding, or image decoding in interaction paths
- [ ] Hitch rate / frame timing checked during the affected interaction, not just averages
- [ ] Images are downsampled to display size before reaching image views
- [ ] Hot loops audited: no accidental CoW copies, membership tests use `Set`, capacity reserved
- [ ] Lazy sequences are single-pass; multi-consumer pipelines are materialized
- [ ] No retain cycles introduced (Leaks clean) and no abandoned memory (generation marking flat across repeated flows)
- [ ] Classes in hot paths are `final`; existentials replaced with generics/enums where the profile showed boxing cost
- [ ] An `XCTMeasure` performance test or MetricKit baseline guards the win against regression
- [ ] Energy-relevant changes (timers, location, networking cadence) reviewed for radio/CPU wake-up cost
- [ ] The diff contains only profile-justified changes — no speculative micro-optimizations riding along
