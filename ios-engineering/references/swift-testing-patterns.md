# Swift Testing & XCTest Patterns

Produce iOS tests that fail only when behavior is wrong — fast, deterministic, and readable
enough that a failure message alone tells you what broke.

## Overview

A test suite earns its keep through trust: when it's green you ship, when it's red you know
exactly what broke. That trust dies through flakiness (sleeps, real network, shared state) and
through tests welded to implementation details that fail on every refactor. The core
philosophy: **test behavior through public seams, isolate every external dependency behind a
protocol, and keep the UI-test layer thin** — most "UI tests" people write are really logic
tests that belong three layers down, where they run a thousand times faster. As of 2026, **Swift
Testing is the default** for new unit, integration, and parameterized tests; **XCTest** is kept
for what Swift Testing doesn't cover — XCUITest journeys, `measure(metrics:)` performance tests,
and Objective-C interop. Both frameworks coexist in the same test target, even the same file, so
adopting Swift Testing for new tests never requires migrating existing `XCTestCase` suites first.

## Core Concepts

### Swift Testing is the default; XCTest is the exception, not the fallback

New test code reaches for `@Test` functions, `#expect`/`#require`, and `@Suite` structs — not
`XCTestCase` subclasses. Swift Testing tests run in parallel by default, use macros instead of
40+ `XCTAssert*` variants, and read closer to plain Swift. Existing `XCTestCase` suites don't need
migrating to adopt this — leave them where they are and write *new* tests in Swift Testing; the
two frameworks run side by side in the same target. Reach for XCTest specifically for XCUITest
(Swift Testing has no UI-test runner), `measure(metrics:)` performance baselines (no Swift Testing
equivalent yet), and Objective-C-visible test code.

### Arrange/Act/Assert, one behavior per test

Every test reads as three visible blocks: build the world, do the one thing, check the outcome.
One *behavior* per test (a behavior may need two `#expect`s; that's fine) — because when
`submit_withExpiredCard_showsRenewalPrompt` fails, the name *is* the diagnosis. A test asserting
five behaviors fails as "something in checkout broke," which forces a debugging session for
information the test should have given away free.

### Protocols are the seams; inject, don't intercept

Anything nondeterministic or external — network, clock, persistence, randomness, analytics —
hides behind a protocol the production type receives in its initializer (see
`ios-service-generator.md`). The test passes a mock. By default that mock is hand-rolled: there's
no mocking framework in mainline Swift, and hand-rolled mocks (10 lines each) are clearer than
any framework anyway — but check for an existing generator first (Mockolo/Sourcery config, a
mocking package already in the project) and follow it if one's there rather than introducing a
second mocking style. Mock only what you own and only at architectural boundaries: when a test
mocks five collaborators to assert call order, it's testing wiring, not behavior, and will break
on every refactor.

### Stub vs. spy vs. mock — know which you're writing

A **stub** supplies canned answers (queue a fake response). A **spy** records what happened
(captured requests) for the test to inspect. Most test doubles are both, and that's the sweet
spot: stub the inputs, assert sparingly on the recorded outputs. Assert on *interactions* only
when the interaction is the contract (e.g., "analytics event fired once") — otherwise assert
on resulting state.

### async by default; `confirmation()` for the callback gaps

`@Test` functions are `async` natively — no `XCTestExpectation` ceremony for code you can just
`await`. For what `await` genuinely can't express (callback-based APIs you can't convert,
`NotificationCenter`, delegate callbacks), Swift Testing's `confirmation(_:expectedCount:)` is the
direct replacement for `XCTestExpectation`, including the inverted case (`expectedCount: 0`). A
timeout is a *failure deadline*, not a synchronization mechanism — `sleep`-then-assert is how
flaky suites are born, in either framework.

### Exit tests and attachments close two former gaps

Code that's *supposed* to terminate the process — a `fatalError`, a `precondition` failure, a
CLI's exit code — used to be untestable without taking the whole test run down with it.
`#expect(processExitsWith: .failure) { ... }` runs the closure in a child process and asserts on
how it exited, so the crash is contained and reported as one clean failure instead of killing the
suite. Separately, `Attachment.record(value, named:)` attaches arbitrary `Attachable` data (raw
bytes, a decoded response, a `UIImage`) to a test's result — visible in Xcode's report and written
to disk for CI — for triaging *why* a failure happened without reproducing it locally first.

### Traits and parameterization are native, not bolted on

`@Test(arguments:)` replaces the manual "array of cases + a loop + `XCTContext.runActivity`"
pattern — Swift Testing runs each argument as its own reported test case automatically, with the
failing input in the output for free. Traits (`.tags(...)`, `.disabled(...)`, `.timeLimit(...)`,
`.bug(...)`) attach metadata directly to the `@Test` declaration instead of living in comments or
external config.

### Parallel by default changes what "isolated" means

Swift Testing runs tests in parallel within a suite by default — a real behavior change from
XCTest's serial-by-default execution. Shared mutable state (a singleton, a shared on-disk store,
a static cache) that was merely bad practice under XCTest becomes an active source of flaky,
order-dependent failures under Swift Testing. Each test must construct and own its world; reach
for the `.serialized` trait on a `@Suite` only when tests genuinely can't run concurrently (a
shared external resource with no per-test isolation option) — not as a default workaround for
poorly isolated tests.

### The unit/UI boundary: UI tests verify wiring, units verify logic

XCUITest (still XCTest-based — Swift Testing has no UI-test runner) runs in a separate process,
driving the real app over accessibility — seconds per interaction, no access to app internals,
flaky by nature. So the division of labor: unit tests own all logic, formatting, validation, and
state transitions (via view models); UI tests own a handful of critical journeys ("log in, add to
cart, check out") proving the screens are wired together. If a UI test asserts a price
*calculation*, it's a unit test paying a 100× tax.

### Fixtures and isolation: every test builds its own world

Shared mutable state (singletons, real `UserDefaults`, a shared persistence stack, leftover
files) makes tests order-dependent — pass alone, fail in the suite, and fail *more visibly* under
Swift Testing's default parallelism. Each test constructs its own dependencies: an in-memory
`ModelContainer` or Core Data store (see `swiftdata-schema-designer.md`), a
`UserDefaults(suiteName:)` wiped per test, builder-pattern fixtures with defaults so tests state
only what matters (`Order.fixture(status: .expired)` — the noise stays in the builder).

## Decision Framework

| Question | Answer |
|---|---|
| Logic, validation, state transition, formatting? | Swift Testing `@Test` against the model/view-model — never XCUITest |
| Critical multi-screen user journey? | One XCUITest per journey; assert on accessibility-identified elements |
| Code under test is `async`? | `@Test func x() async throws` + `await`; no expectations needed |
| Callback/delegate/Notification API? | `confirmation(_:expectedCount:)`; `expectedCount: 0` for "this must NOT happen" |
| Need to fake the network? | Protocol stub at your API-client seam (default); `URLProtocol` stub only to test the client itself (see `ios-networking.md`) |
| Same logic, many input/output cases? | `@Test(arguments:)` with an array of cases — no manual loop, no `XCTContext.runActivity` |
| Persistence in tests? | In-memory store built per-test, torn down after — construct fresh per `@Test`, not shared via a suite-level `let` |
| Measuring speed/memory? | XCTest `measure(metrics:)` with a recorded baseline — no Swift Testing equivalent yet; keep this one test in an `XCTestCase` |
| Code expected to crash (`fatalError`/`precondition`)? | `#expect(processExitsWith: .failure) { ... }` — runs in a child process, isolates the crash to one clean failure |
| Failure needs debug data attached (response body, screenshot)? | `Attachment.record(value, named:)` — surfaces in Xcode's report and CI artifacts |
| Singleton in the way? | Wrap it in a protocol, inject; don't mutate the singleton in tests |
| Tests need to run one-at-a-time (shared external resource)? | `.serialized` trait on the `@Suite` — sparingly, as an exception, not a default |
| Existing suite is XCTestCase-based? | Leave it; write new tests in Swift Testing in the same target rather than migrating wholesale |

## Workflow

1. **Read the existing code and test targets.** Note the DI style (initializer injection?
   environment? singletons), existing mocks/fixtures to reuse and how they're produced
   (hand-written, or generated — grep for Mockolo/Sourcery config), whether the target already
   uses Swift Testing, XCTest, or both, and how CI runs tests. Match the house style; default new
   tests to Swift Testing regardless of whether existing tests are XCTest-based.
2. **Identify the behaviors to test** — from the bug report, acceptance criteria, or the public
   API of the type. List them as future test names first; untestable names reveal design
   problems early.
3. **Carve the seams**: introduce protocols for any direct dependency on network/clock/storage
   the type currently hardwires. This is a production refactor — keep it minimal and separate
   from the tests themselves.
4. **Build doubles and fixtures**: hand-rolled (or generator-produced) stub/spy per protocol;
   `fixture()` builders with sensible defaults for domain types.
5. **Write the tests** as `@Test` functions in Arrange/Act/Assert form, one behavior each,
   covering the happy path, each failure path, and the boundary cases (empty, nil, maximum,
   cancelled). Use `@Test(arguments:)` the moment two or more cases share shape.
6. **Cover async paths properly**: `async` tests for async APIs, `confirmation()` for callbacks,
   explicit tests for cancellation and error propagation.
7. **Add the UI-journey test only if this change affects a critical flow**, as an `XCTestCase`
   XCUITest using accessibility identifiers set in production code.
8. **Run the suite repeatedly** (Xcode's repeat-until-failure option) to flush flakiness —
   parallel-by-default Swift Testing execution surfaces shared-state bugs faster than XCTest did
   — confirm each new test fails when the behavior is broken (mutate or revert the fix briefly),
   then verify against the Quality Checklist.
9. **In an agentic session, default any `xcodebuild` invocation (build, test, or
   build-for-testing) to filtered output** — the raw log is mostly build-graph noise (Copy,
   CodeSign, Touch lines) and burns context fast for no signal. Pipe through a formatter if one's
   installed (`xcodebuild ... | xcbeautify`), or fall back to a grep filter that keeps the
   pass/fail signal:
   ```sh
   xcodebuild test -scheme MyApp -destination '...' 2>&1 \
     | grep -E '✔|✘|error:|BUILD (SUCCEEDED|FAILED)|TEST (BUILD|EXECUTE) (SUCCEEDED|FAILED)'
   ```
   Only re-run unfiltered (or inspect the `.xcresult` bundle the log points to) when a failure
   needs the surrounding build/compiler context to diagnose.

## Patterns

### Unit test structure

```swift
import Testing

struct CheckoutModelTests {
    @Test
    func submit_withExpiredCard_failsWithRenewalError() async {
        // Arrange
        let api = CheckoutAPIMock()
        api.stubbedResult = .failure(.cardExpired)
        let sut = CheckoutModel(api: api, cart: .fixture(items: 2))

        // Act
        await sut.submit()

        // Assert
        #expect(sut.state == .failed(.cardExpired))
        #expect(api.submittedCarts.count == 1)
    }
}
```

### Protocol seam + hand-rolled mock (stub + spy in one)

```swift
protocol CheckoutAPI {
    func submit(_ cart: Cart) async throws -> Receipt
}

final class CheckoutAPIMock: CheckoutAPI {
    var stubbedResult: Result<Receipt, CheckoutError> = .success(.fixture())
    private(set) var submittedCarts: [Cart] = []        // spy

    func submit(_ cart: Cart) async throws -> Receipt {
        submittedCarts.append(cart)
        return try stubbedResult.get()                   // stub
    }
}
```

### Fixture builders — tests state only what matters

```swift
extension Cart {
    static func fixture(
        id: UUID = UUID(),
        items: Int = 1,
        currency: Currency = .usd
    ) -> Cart {
        Cart(id: id, items: (0..<items).map { _ in .fixture() }, currency: currency)
    }
}
```

### Parameterized cases — no loop, no manual activity naming

```swift
@Test(arguments: [
    ("", PasswordVerdict.tooShort),
    ("abcdefgh", .needsDigit),
    ("abcdefg1", .valid),
])
func passwordValidator_rules(input: String, expected: PasswordVerdict) {
    #expect(PasswordValidator.check(input) == expected)
}
```

Each argument tuple runs and reports as its own test case automatically — the failing input is in
the output without any `line:`/activity-naming bookkeeping.

### `confirmation()` for callback APIs (and the inverted case)

```swift
@Test
func locationManager_emitsFixWithinTimeout() async {
    await confirmation("location fix delivered") { confirm in
        sut.onFix = { _ in confirm() }
        sut.start()
        try? await Task.sleep(for: .seconds(2))   // deadline, not the synchronization mechanism
    }
}

@Test
func analytics_notFiredForCachedLoads() async {
    await confirmation("analytics fired", expectedCount: 0) { confirm in
        analytics.onEvent = { _ in confirm() }
        sut.load(fromCache: true)
        try? await Task.sleep(for: .milliseconds(500))
    }
}
```

### `URLProtocol` stub — for testing the network client itself

```swift
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

// let config = URLSessionConfiguration.ephemeral
// config.protocolClasses = [StubURLProtocol.self]
```

Everything *above* the API client should mock the protocol seam instead — it's simpler and
doesn't drag URLSession into tests that aren't about HTTP. Framework-agnostic: usable from either
a Swift Testing `@Test` or an `XCTestCase`.

### UI test for a critical journey (still XCTest — Swift Testing has no UI-test runner)

```swift
final class CheckoutJourneyUITests: XCTestCase {
    func test_checkoutJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]              // app swaps in stubbed services
        app.launch()

        app.buttons["catalog.item.widget"].tap()          // accessibilityIdentifier, not labels
        app.buttons["detail.addToCart"].tap()
        app.buttons["cart.checkout"].tap()

        XCTAssertTrue(app.staticTexts["checkout.confirmation"]
            .waitForExistence(timeout: 5))                // condition wait, never sleep
    }
}
```

### Performance test (still XCTest — no Swift Testing equivalent yet)

```swift
final class FeedDiffPerformanceTests: XCTestCase {
    func testFeedDiffPerformance() {
        let old = PostFixtures.posts(count: 5_000)
        let new = PostFixtures.shuffled(old)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = FeedDiffer.diff(old: old, new: new)
        }
    }
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Test passes locally, fails on CI (or 1 run in 20) | `sleep`/`DispatchQueue.asyncAfter` used as synchronization | `await` the real operation, or `confirmation()`/`XCTestExpectation` + `wait(for:)`; condition waits in UI tests |
| Tests pass alone, fail in the suite (new under Swift Testing's default parallelism) | Shared state: singletons, real `UserDefaults`, shared store, statics not reset | Per-test isolated stores; construct fixtures fresh in each `@Test`, not shared at `@Suite` scope; `.serialized` only as a last resort |
| Every refactor breaks dozens of tests, behavior unchanged | Asserting on internals and call sequences instead of outcomes | Test through the public API; assert resulting state; verify interactions only where the call *is* the contract |
| Suite takes 20 minutes | Logic tested through XCUITest; real network in unit tests | Push logic tests down to `@Test`s with mocked seams; cap UI tests to a few journeys |
| Crash mid-run instead of one clean failure | Force unwraps in test code | `try #require(...)` — fails the single test with a message instead of killing the run |
| Async test passes even though the code is broken | Forgot to `await`, or `confirm()` called before the operation under test ran | Make the test fail first by breaking the code; prefer `async`/`await` over manual synchronization |
| UI tests break on every copy change | Querying by visible label text | Stable `accessibilityIdentifier`s set in production code |
| Mock setup is 40 lines per test | Over-mocking: every collaborator, every call stubbed | Mock only architectural boundaries; use fixture builders with defaults; consider a real (in-memory) implementation |
| Inverted `confirmation(expectedCount: 0)` always passes | Window too short for the forbidden event to occur at all | Pair with a positive-control test proving the event *does* fire in the non-cached path |
| Persistence tests slow and cross-contaminated | Shared on-disk store (Core Data or SwiftData) across tests | Fresh in-memory `ModelContainer`/`NSPersistentContainer` per test; never share one across tests |
| Test crashes and kills the whole run instead of failing cleanly | Precondition/`fatalError` code tested inline instead of via an exit test | `#expect(processExitsWith: .failure) { ... }` — the crash happens in a disposable child process |
| Migrating every existing `XCTestCase` to Swift Testing before writing new tests | Treating the migration as a prerequisite instead of incidental | Write new tests in Swift Testing now; migrate old suites opportunistically, if at all — both frameworks coexist indefinitely |

## Quality Checklist

- [ ] New tests are Swift Testing `@Test`/`@Suite`; XCTest is used only for XCUITest,
      `measure(metrics:)`, or Objective-C interop
- [ ] No `sleep`/arbitrary delays anywhere; all waiting is `await`, `confirmation()`,
      `XCTestExpectation`, or `waitForExistence`
- [ ] Every test owns its world: no shared mutable state, in-memory persistence, suite passes
      under Swift Testing's default parallel execution
- [ ] `.serialized` is applied only where a genuine shared external resource forces it, not as a
      default fix for poor isolation
- [ ] Each new test was seen to fail when the behavior is broken (red before green)
- [ ] Tests assert behavior/outcomes through public API; interaction asserts only where the
      interaction is the contract
- [ ] External dependencies (network, clock, storage, randomness, analytics) injected via
      protocols and doubled in tests
- [ ] Same-shape cases use `@Test(arguments:)` instead of a manual loop
- [ ] No force unwraps in tests — `#require`/`XCTUnwrap` used instead
- [ ] Code expected to crash (precondition/`fatalError`) is verified via an exit test, not left
      untested or allowed to take down the run
- [ ] Test names/parameters state the scenario and expected outcome
- [ ] Logic lives in unit tests; XCUITest covers only critical journeys via accessibility
      identifiers with launch-argument stubbing
- [ ] Fixtures use builder defaults so each test specifies only the relevant fields
- [ ] Error paths, cancellation, and boundary inputs (empty/nil/max) are covered, not just the
      happy path
- [ ] Performance assertions live in dedicated XCTest `measure(metrics:)` tests with baselines,
      separate from behavior tests
