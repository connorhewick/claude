# iOS Networking Patterns

Design HTTP clients for iOS using URLSession, async/await, and Codable with a strict error taxonomy, principled retries, and URLProtocol-based testing.

---

## Overview

A production iOS networking layer is three thin layers — **Endpoint** (a value describing a request), **Client** (one generic type that executes any endpoint), and **Service** (domain methods that return decoded models) — built on async/await URLSession. The philosophy: every network failure must land in exactly one of three buckets (transport, HTTP, decoding) so callers can make a *policy* decision (retry, re-auth, surface, log) without string-matching error messages. Everything else — retries, token refresh, pinning — is middleware around that core, and all of it must be testable without a server.

## Core Concepts

**Async/await is the default; Combine is an adapter, not a foundation.** `URLSession.data(for:)` cooperates with structured concurrency: cancel the enclosing `Task` and the request cancels too, for free. Combine publishers require manual `AnyCancellable` lifetime management, which is the single biggest source of leaked requests in legacy code. Only expose a publisher when an existing Combine pipeline consumes it — and build it by wrapping the async call, not the other way around.

**Isolation is explicit, not inherited.** New projects default to `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (SE-0466), and an unannotated `async` call now runs in the *caller's* context instead of hopping off main (SE-0461) — so a networking layer with no isolation annotation of its own silently runs on the main actor the moment a `@MainActor` view model calls it. Mark the client and its free functions `nonisolated` explicitly; reserve `@concurrent` for CPU-bound work inside it — decoding a large payload — that genuinely needs a background thread.

**Endpoints are values, clients are machines.** A request is *data*: method, path, query, headers, body. Encode that as a struct conforming to an `Endpoint` protocol. The client is the only place that knows about `URLSession`, JSON coders, retries, and auth. Because endpoints are values, you can log them, diff them in tests, and add a new API call without touching the client. If adding an endpoint requires editing the client, the layering is wrong.

**The error taxonomy is the contract.** There are exactly three failure families, and they demand different responses:
- **Transport** (`URLError`): the bytes never arrived — offline, timeout, cancelled, TLS failure. Often retryable; never the server's fault.
- **HTTP** (status ≥ 400 with a response body): the server answered and said no. `401` means refresh auth, `429`/`503` mean back off, `4xx` otherwise means *your request is wrong — retrying is pointless*.
- **Decoding** (`DecodingError`): the server answered 2xx but the payload doesn't match your `Codable` model. This is a *programming or contract bug*, never retryable; log the raw body (truncated, redacted) or you will never diagnose it.

Collapsing these into one generic `NetworkError.unknown` is the root cause of apps that retry malformed requests forever and silently eat schema drift.

**Token refresh must be single-flight.** When a token expires, every in-flight request gets a 401 at once. If each one independently calls the refresh endpoint, you get a thundering herd — and with rotating refresh tokens, the second refresh *invalidates the first*, logging the user out. The fix is an `actor` that coalesces concurrent refresh requests into one shared `Task`.

**Retry is policy, not reflex.** Retry only what is safe (idempotent: GET/PUT/DELETE, or POSTs with an idempotency key) and only what might succeed (transport timeouts, 429, 5xx). Use exponential backoff with jitter, honor `Retry-After`, cap attempts at 2–3. Retrying a 400 burns battery and hammers a server that already told you no.

**Test the layer with `URLProtocol`, not by mocking the client.** A mock client proves your mock works. A `URLProtocol` stub injected via `URLSessionConfiguration.protocolClasses` exercises your *real* request construction, header injection, decoding, and error mapping — the code that actually breaks.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| async/await or Combine? | async/await | Structured cancellation, no cancellable bookkeeping; wrap in a publisher only at a legacy seam |
| `URLSession.shared` or custom session? | Custom, injected | You need `protocolClasses` for tests, timeout config, and a delegate for pinning |
| Retry this failure? | Transport timeout / 429 / 5xx on idempotent request → yes; 4xx (≠429) / decoding → never | Server-said-no and contract bugs cannot be fixed by repetition |
| Where does auth live? | Client middleware (adapter + refresher), not endpoints | Endpoints stay declarative; one place rotates tokens |
| Background transfer? | `URLSession(configuration: .background)` with delegate, only for large up/downloads that must survive suspension | Background sessions can't use async/await bodies and add huge complexity — don't default to them |
| Decode where? | In the client, generically (`Decodable` constraint) | One decoder config (dates, key strategy) — per-call decoding drifts |
| Errors as `Error` or typed enum? | One public `APIError` enum with three cases wrapping the underlying errors | Callers switch on policy, not on `localizedDescription` |
| Client actor isolation? | Explicit `nonisolated` (or its own actor) — never left to inherit the default | Under SE-0466 default main-actor isolation, an unannotated client silently pins itself to `@MainActor` |

## Workflow

1. **Read the existing code.** Find current networking (search for `URLSession`, `Alamofire`, `dataTask`, `AnyPublisher`), the deployment target, existing `Codable` models, and how auth tokens are stored. Match conventions; do not introduce a second parallel client.
2. **Define `APIError`** with the three-bucket taxonomy first — it shapes every signature downstream.
3. **Define the `Endpoint` protocol** and one concrete endpoint for the first real call, including its `Decodable` response model.
4. **Build the client**: injected `URLSession` + `JSONDecoder`, generic `send`, status-code validation, error mapping. No auth or retry yet — get the happy path and taxonomy right.
5. **Add middleware**: request adapter (default headers, auth token), single-flight `TokenRefresher` actor, retry policy with backoff. Each is a small, separately testable unit.
6. **Add pinning/ATS hooks if required** (delegate-based challenge handling — see `ios-security.md` for the trade-offs).
7. **Write `URLProtocol` tests**: one per error bucket, one for 401→refresh→replay, one for retry/backoff (with injected sleep), one asserting exact headers/URL of a built request.
8. **Verify against the Quality Checklist** below before declaring done.

## Patterns

### Error taxonomy

```swift
enum APIError: Error {
    case transport(URLError)                       // bytes never arrived
    case http(status: Int, data: Data)             // server said no
    case decoding(DecodingError, raw: Data)        // 2xx but payload ≠ contract

    var isRetryable: Bool {
        switch self {
        case .transport(let e):
            return [.timedOut, .networkConnectionLost, .cannotConnectToHost].contains(e.code)
        case .http(let status, _):
            return status == 429 || (500...599).contains(status)
        case .decoding:
            return false
        }
    }
}
```

### Endpoint as a value

```swift
protocol Endpoint {
    associatedtype Response: Decodable
    var path: String { get }
    var method: String { get }
    var query: [URLQueryItem] { get }
    var body: Data? { get }
    var requiresAuth: Bool { get }
}

struct GetUser: Endpoint {
    typealias Response = User
    let id: UUID
    var path: String { "/v1/users/\(id)" }
    var method: String { "GET" }
    var query: [URLQueryItem] { [] }
    var body: Data? { nil }
    var requiresAuth: Bool { true }
}
```

### Generic client with strict mapping

```swift
nonisolated final class APIClient: Sendable {
    private let session: URLSession        // injected — tests pass a URLProtocol-backed one
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let refresher: TokenRefresher

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        var request = makeRequest(endpoint)
        if endpoint.requiresAuth {
            request.setValue("Bearer \(try await refresher.validToken())",
                             forHTTPHeaderField: "Authorization")
        }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError { throw APIError.transport(error) }

        let status = (response as! HTTPURLResponse).statusCode
        if status == 401, endpoint.requiresAuth {
            try await refresher.refresh()
            return try await send(endpoint)               // one replay; refresh throws on 2nd 401
        }
        guard (200..<300).contains(status) else { throw APIError.http(status: status, data: data) }
        do { return try decoder.decode(E.Response.self, from: data) }
        catch let error as DecodingError { throw APIError.decoding(error, raw: data) }
    }
}
```

### Single-flight token refresh (actor)

```swift
actor TokenRefresher {
    private var token: Token
    private var inFlight: Task<Token, Error>?

    func validToken() async throws -> String {
        if token.isExpired { try await refresh() }
        return token.accessToken
    }

    func refresh() async throws {
        if let inFlight {                                  // coalesce the herd
            token = try await inFlight.value
            return
        }
        let task = Task { try await performRefreshCall(token.refreshToken) }
        inFlight = task
        defer { inFlight = nil }
        token = try await task.value                       // failure here ⇒ force re-login upstream
    }
}
```

### Retry with capped exponential backoff + jitter

```swift
nonisolated func withRetry<T>(maxAttempts: Int = 3,
                  operation: () async throws -> T) async throws -> T {
    for attempt in 1... {
        do { return try await operation() }
        catch let error as APIError where error.isRetryable && attempt < maxAttempts {
            let delay = min(pow(2.0, Double(attempt)), 30) * Double.random(in: 0.5...1.0)
            try await Task.sleep(for: .seconds(delay))     // respects Task cancellation
        }
    }
    fatalError("unreachable")
}
```

### Deterministic tests with URLProtocol

```swift
final class StubProtocol: URLProtocol {
    static nonisolated(unsafe) var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
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

// In tests:
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [StubProtocol.self]
let client = APIClient(session: URLSession(configuration: config), ...)
// StubProtocol.handler asserts on the *real* outgoing request, then returns canned bytes.
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Requests keep running after the screen is dismissed | Detached `Task` or stored Combine cancellables outliving the view | Use `.task {}` in SwiftUI / cancel the owning `Task` in `deinit`; async URLSession cancels with the task |
| User logged out randomly under load | Concurrent token refreshes; second refresh invalidates the first's rotated token | Single-flight `TokenRefresher` actor (pattern above) |
| App hammers server during an outage | Retrying all errors, no backoff, no cap | Retry only `isRetryable`, exponential backoff + jitter, max 3 attempts, honor `Retry-After` |
| "The data couldn't be read" with no further info | `DecodingError` swallowed into a generic error | `.decoding` case carries the raw body; log it (redacted) with the failing key path |
| Duplicate orders/payments after flaky network | Retrying non-idempotent POSTs | Only retry idempotent requests, or attach an `Idempotency-Key` header the server deduplicates |
| UI hangs during requests | Synchronous waits (`DispatchSemaphore`) bridging async code, or an unannotated client silently inheriting `@MainActor` under SE-0466 default isolation | Never block; mark the client `nonisolated` explicitly, hop to main only for UI state; use `@concurrent` for heavy decoding |
| Tests are flaky and slow | Hitting a real staging server | `URLProtocol` stubs + injected session; inject the sleep in retry tests |
| 401 loop drains battery | Replaying after refresh without a replay cap | Replay exactly once; a second 401 escalates to forced re-login |
| Mysterious stale responses | `URLCache` serving cached GETs during debugging | Use `.ephemeral` configuration in tests; set explicit `cachePolicy` where freshness matters |

## Quality Checklist

- [ ] Every thrown error is one of the three `APIError` cases — no raw `URLError`/`DecodingError` escapes the client
- [ ] Token refresh is single-flight (actor) and a refreshed request replays at most once
- [ ] Retries: idempotent + retryable errors only, exponential backoff with jitter, hard attempt cap, `Retry-After` honored
- [ ] No secrets in code: tokens come from Keychain (see `ios-security.md`), never hardcoded or in `UserDefaults`
- [ ] `URLSession` and `JSONDecoder` are injected — no `URLSession.shared` reachable from production paths used in tests
- [ ] Cancellation propagates: cancelling the caller's `Task` cancels the request and any backoff sleep
- [ ] Decoding failures log the raw body (truncated, PII-redacted) and the `DecodingError` key path
- [ ] Client (and its free functions) is explicitly `nonisolated` — not left to inherit `@MainActor` under default isolation; only published UI state hops to main
- [ ] `URLProtocol` tests cover: each error bucket, 401→refresh→replay, retry policy, exact request shape
- [ ] One `JSONDecoder` configuration (date strategy, key strategy) defined once in the client
- [ ] Endpoints contain no `URLSession`, auth, or retry logic — pure values
- [ ] HTTPS only; any pinning lives in the session delegate with a documented rotation plan (see `ios-security.md`)
