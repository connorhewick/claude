# XCTest Patterns

Produce iOS tests that fail only when behavior is wrong — fast, deterministic, and readable
enough that a failure message alone tells you what broke.

## Overview

A test suite earns its keep through trust: when it's green you ship, when it's red you know
exactly what broke. That trust dies through flakiness (sleeps, real network, shared state) and
through tests welded to implementation details that fail on every refactor. The core
philosophy: **test behavior through public seams, isolate every external dependency behind a
protocol, and keep the UI-test layer thin** — most "UI tests" people write are really logic
tests that belong three layers down, where they run a thousand times faster.

## Core Concepts

### Arrange/Act/Assert, one behavior per test

Every test reads as three visible blocks: build the world, do the one thing, check the
outcome. One *behavior* per test (a behavior may need two assertions; that's fine) — because
when `test_submit_withExpiredCard_showsRenewalPrompt` fails, the name *is* the diagnosis.
A test asserting five behaviors fails as "something in checkout broke," which forces a
debugging session for information the test should have given away free.

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

### async/await first; expectations for the gaps

With `@MainActor`-aware XCTest, an `async` test function plus `await` replaces most
`XCTestExpectation` ceremony — straighter code, real failures instead of timeout ambiguity.
Expectations remain the right tool for what `await` can't express: callback-based APIs you
can't convert, NotificationCenter, delegate callbacks, and `isInverted` ("this must NOT
happen"). A timeout in a test is a *failure deadline*, not a synchronization mechanism —
`sleep`-then-assert is how flaky suites are born.

### The unit/UI boundary: UI tests verify wiring, units verify logic

XCUITest runs in a separate process, driving the real app over accessibility — seconds per
interaction, no access to app internals, flaky by nature. So the division of labor: unit tests
own all logic, formatting, validation, and state transitions (via view models); UI tests own a
handful of critical journeys ("log in, add to cart, check out") proving the screens are wired
together. If a UI test asserts a price *calculation*, it's a unit test paying a 100× tax.

### Fixtures and isolation: every test builds its own world

Shared mutable state (singletons, real `UserDefaults`, a shared Core Data stack, leftover
files) makes tests order-dependent — pass alone, fail in the suite. Each test constructs its
own dependencies: in-memory Core Data (`NSInMemoryStoreType` / in-memory `ModelContainer` — see
`coredata-schema-designer.md`), a `UserDefaults(suiteName:)` wiped in `setUp`, builder-pattern
fixtures with defaults so tests state only what matters (`Order.fixture(status: .expired)` —
the noise stays in the builder).

## Decision Framework

| Question | Answer |
|---|---|
| Logic, validation, state transition, formatting? | Unit test against the model/view-model — never XCUITest |
| Critical multi-screen user journey? | One XCUITest per journey; assert on accessibility-identified elements |
| Code under test is `async`? | `func test_x() async throws` + `await`; no expectations |
| Callback/delegate/Notification API? | `XCTestExpectation` + `fulfill()`, generous timeout (test speed ≠ timeout size) |
| Must assert something does NOT happen? | Inverted expectation (`isInverted = true`) with a short window |
| Need to fake the network? | Protocol stub at your API-client seam (default); `URLProtocol` stub only to test the client itself (see `ios-networking.md`) |
| Same logic, many input/output cases? | Parameterized: array of cases + `XCTContext.runActivity` per case (or Swift Testing `@Test(arguments:)` if the project has adopted it) |
| Persistence in tests? | In-memory store built per-test in `setUp`, torn down in `tearDown` |
| Measuring speed/memory? | `measure(metrics:)` with a recorded baseline — separate test, not mixed into behavior tests |
| Singleton in the way? | Wrap it in a protocol, inject; don't mutate the singleton in tests |

## Workflow

1. **Read the existing code and test targets.** Note the DI style (initializer injection?
   environment? singletons), existing mocks/fixtures to reuse and how they're produced
   (hand-written, or generated — grep for Mockolo/Sourcery config), `@testable import` targets,
   and how CI runs tests. Match the house style before adding a new one.
2. **Identify the behaviors to test** — from the bug report, acceptance criteria, or the public
   API of the type. List them as future test names first; untestable names reveal design
   problems early.
3. **Carve the seams**: introduce protocols for any direct dependency on network/clock/storage
   the type currently hardwires. This is a production refactor — keep it minimal and separate
   from the tests themselves.
4. **Build doubles and fixtures**: hand-rolled stub/spy per protocol; `fixture()` builders with
   sensible defaults for domain types.
5. **Write the tests** in Arrange/Act/Assert form, one behavior each, covering the happy path,
   each failure path, and the boundary cases (empty, nil, maximum, cancelled).
6. **Cover async paths properly**: async tests for async APIs, expectations for callbacks,
   explicit tests for cancellation and error propagation.
7. **Add the UI-journey test only if this change affects a critical flow**, using accessibility
   identifiers set in production code.
8. **Run the suite repeatedly** (`-test-iterations 10` or scheme's repeat option) to flush
   flakiness, confirm each new test fails when the behavior is broken (mutate or revert the
   fix briefly), then verify against the Quality Checklist.

## Patterns

### Unit test structure

```swift
final class CheckoutModelTests: XCTestCase {
    func test_submit_withExpiredCard_failsWithRenewalError() async {
        // Arrange
        let api = CheckoutAPIMock()
        api.stubbedResult = .failure(.cardExpired)
        let sut = CheckoutModel(api: api, cart: .fixture(items: 2))

        // Act
        await sut.submit()

        // Assert
        XCTAssertEqual(sut.state, .failed(.cardExpired))
        XCTAssertEqual(api.submittedCarts.count, 1)
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

### XCTestExpectation for callback APIs (and the inverted case)

```swift
func test_locationManager_emitsFixWithinTimeout() {
    let fix = expectation(description: "location fix delivered")
    sut.onFix = { _ in fix.fulfill() }

    sut.start()

    wait(for: [fix], timeout: 2.0)   // deadline, not a sleep
}

func test_analytics_notFiredForCachedLoads() {
    let fired = expectation(description: "analytics fired")
    fired.isInverted = true
    analytics.onEvent = { _ in fired.fulfill() }

    sut.load(fromCache: true)

    wait(for: [fired], timeout: 0.5)
}
```

### Parameterized cases with per-case reporting

```swift
func test_passwordValidator_rules() {
    struct Case { let input: String; let expected: PasswordVerdict; let line: UInt }
    let cases: [Case] = [
        .init(input: "",            expected: .tooShort,   line: #line),
        .init(input: "abcdefgh",    expected: .needsDigit, line: #line),
        .init(input: "abcdefg1",    expected: .valid,      line: #line),
    ]
    for c in cases {
        XCTContext.runActivity(named: "input: \(c.input)") { _ in
            XCTAssertEqual(PasswordValidator.check(c.input), c.expected, line: c.line)
        }
    }
}
```

`line:` makes the failure point at the offending case, not the assertion inside the loop.

### URLProtocol stub — for testing the network client itself

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
doesn't drag URLSession into tests that aren't about HTTP.

### UI test for a critical journey

```swift
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
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Test passes locally, fails on CI (or 1 run in 20) | `sleep`/`DispatchQueue.asyncAfter` used as synchronization | `await` the real operation, or expectation + `wait(for:)`; condition waits in UI tests |
| Tests pass alone, fail in suite (or order-dependent) | Shared state: singletons, real `UserDefaults`, shared DB, statics not reset | Per-test isolated stores; reset injected state in `setUp`; spies as instance properties |
| Every refactor breaks dozens of tests, behavior unchanged | Asserting on internals and call sequences instead of outcomes | Test through the public API; assert resulting state; verify interactions only where the call *is* the contract |
| Suite takes 20 minutes | Logic tested through XCUITest; real network in unit tests | Push logic tests down to view models with mocked seams; cap UI tests to a few journeys |
| `Fatal error: Unexpectedly found nil` crashes the test run | Force unwraps in test code | `try XCTUnwrap(...)` — fails the single test with a message instead of killing the process |
| Async test passes even though the code is broken | Forgot to `await`, or expectation fulfilled in Arrange before Act | Make the test fail first by breaking the code; prefer async/await over expectations |
| UI tests break on every copy change | Querying by visible label text | Stable `accessibilityIdentifier`s set in production code |
| Mock setup is 40 lines per test | Over-mocking: every collaborator, every call stubbed | Mock only architectural boundaries; use fixture builders with defaults; consider a real (in-memory) implementation |
| Inverted expectation always passes | Window too short for the forbidden event to occur at all | Pair with a positive control test proving the event *does* fire in the non-cached path |
| Core Data tests slow and cross-contaminated | Shared on-disk store across tests | Fresh in-memory store per test in `setUp`; never share an `NSPersistentContainer` between tests |

## Quality Checklist

- [ ] No `sleep`/arbitrary delays anywhere; all waiting is `await`, expectations, or `waitForExistence`
- [ ] Every test owns its world: no shared mutable state, in-memory persistence, suite passes under repeated and randomized execution
- [ ] Each new test was seen to fail when the behavior is broken (red before green)
- [ ] Tests assert behavior/outcomes through public API; interaction asserts only where the interaction is the contract
- [ ] External dependencies (network, clock, storage, randomness, analytics) injected via protocols and doubled in tests
- [ ] Async code tested with `async` test functions; expectations reserved for callback/notification APIs and inverted cases
- [ ] No force unwraps in tests — `XCTUnwrap` with the result used
- [ ] Test names state scenario and expected outcome (`test_method_condition_outcome`)
- [ ] Logic lives in unit tests; XCUITest covers only critical journeys via accessibility identifiers with launch-argument stubbing
- [ ] Fixtures use builder defaults so each test specifies only the relevant fields
- [ ] Parameterized tests report the failing case (activity name + `line:`)
- [ ] Error paths, cancellation, and boundary inputs (empty/nil/max) are covered, not just the happy path
- [ ] Performance assertions live in dedicated `measure(metrics:)` tests with baselines, separate from behavior tests
