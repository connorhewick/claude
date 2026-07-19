# iOS Enterprise Service Generator

Scaffolds protocol-first service layers for iOS apps: View → ViewModel → Service → Client/Store, wired with initializer injection and shipped with mocks.

---

## Overview

This skill scaffolds the layer most iOS codebases get wrong: the seam between UI and data. The architecture is deliberately boring — **View → ViewModel → Service → Client/Store** — with a protocol at every downward dependency and all wiring done through initializers. The payoff is mechanical: any ViewModel can be unit-tested with a three-line mock, and swapping REST for GraphQL or Core Data for an in-memory store touches exactly one file (the composition root). The philosophy: protocols are for *seams you actually test or swap*, not ceremony; injection is explicit (initializers), not magical (singletons, property wrappers that hide dependencies).

## Core Concepts

**Layering is about direction of knowledge, not folders.** Views know ViewModels. ViewModels know service *protocols*. Services know client/store *protocols* plus domain rules. Clients/stores know URLSession or Core Data. Nothing knows anything upward, and nothing skips a layer — a View calling `URLSession` directly is the original sin this skill exists to prevent. The reason: every skipped layer is a dependency you can no longer fake in a test or swap in a migration.

**Protocol-first, but only at seams.** Define a protocol for each service and each client/store *because ViewModels are tested against fakes and backends get swapped* — not because "everything should have an interface." A pure value type (`User`, a formatter) needs no protocol. The test: if you'll never write a second implementation (including a mock), the protocol is noise. Keep protocols small and domain-shaped (`UserServicing` with `fetchUser(id:)`), not transport-shaped (`get(path:)` belongs one layer down).

**Initializer injection is the default; Environment is for composition, not hiding.** Every type lists its dependencies as `init` parameters typed as protocols. That makes the dependency graph compile-checked and impossible to miss in review. SwiftUI's `Environment` is the right vehicle for *delivering* app-wide dependencies from the composition root down the view tree (iOS 17: `@Observable` + `.environment(_:)`), but the ViewModel itself still receives them through its initializer — a ViewModel that reads global state is untestable again. Avoid `Foo.shared` reached from inside methods: a hidden dependency is the one that bites in tests.

**The composition root is one file.** `AppDependencies` (or the `App` struct) is the *only* place concrete types are constructed and connected. When someone asks "where do I swap the GraphQL client in?", the answer must be one filename. If concretes are constructed in five ViewModels, you don't have DI — you have distributed hardcoding.

**ViewModels own state and translation; services own domain logic.** A ViewModel converts user intent into service calls and service results into display state (`@Observable` properties, a `ViewState` enum). It contains *no* business rules — those live in services so they're shared across screens and tested without UI. Symmetrically, services return domain models, never view state; the day a service knows about "loading spinners" the layering has inverted.

**Mocks are hand-written and dumb — unless the codebase already generates them.** A mock conforms to the protocol, records the call, and returns a stubbed value. Hand-written mocks (one per protocol, ~10 lines) beat frameworks here by default: Swift's type system makes them trivial, they compile-break loudly when the protocol changes, and there's no reflection magic to debug. But check first — a codebase with Mockolo/Sourcery/SwiftyMocky already wired in (config file, a generator target, a mocking dependency in `Package.swift`/Podfile) has already made this call; extend that convention instead of introducing a second mocking style. Whichever approach applies, generate the mock at the same moment you generate the protocol — a protocol without its mock is half-delivered.

**`@MainActor` on ViewModels, nowhere below.** UI state mutation must be main-thread; annotating the ViewModel class makes that structural. Services and clients stay actor-agnostic (`Sendable`), so work runs off-main and only the published state hops back.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Does this type need a protocol? | Yes for services, clients, stores (tested/swapped seams); no for value types and pure helpers | Protocols exist for substitution; ceremony hides the real seams |
| Initializer injection or Environment? | Initializer always; Environment only to *transport* the container from the app root to view construction | Compile-checked dependencies; Environment-read ViewModels are hidden globals |
| One service per domain or per screen? | Per domain (`UserService`, `OrderService`) | Screens come and go; domains are stable and rules get reused |
| ViewModel per screen or shared? | Per screen, composing shared services | Shared ViewModels accrete unrelated state and become god objects |
| Where do Codable DTOs live? | Client layer, mapped to domain models before crossing into services | Backend field renames shouldn't ripple into ViewModels |
| Class or struct ViewModel? | `@Observable final class`, `@MainActor` | Identity + observation; structs can't hold mutable observed state across async work |
| Mock framework or hand-written? | Hand-written, unless a generator (Mockolo/Sourcery) is already wired in | Compile-time safety, zero dependencies, protocol drift breaks the build not the test run — but matching an existing convention beats a second mocking style |
| Singleton ever? | Only inside the composition root as a held instance — never reached via `.shared` from business code | Lifetime control without hidden coupling |

## Workflow

1. **Read the existing code.** Identify the app's current pattern (MVVM? MVC? TCA?), DI approach, networking layer, minimum iOS version (`@Observable` needs 17; below that use `ObservableObject`), naming conventions, and any existing mock-generation tooling (Mockolo config, Sourcery templates, a mocking package in `Package.swift`/Podfile). Extend what exists; never introduce a second architecture style — or a second mocking approach — for one feature.
2. **Name the domain and its operations.** Agree the service protocol surface first (e.g., `UserServicing: fetchUser, updateProfile`) — it is the contract everything else satisfies.
3. **Generate the domain model** (plain struct) and, in the client layer, the Codable DTO + mapping if the wire format differs (see `swift-codable-designer.md`).
4. **Generate the client/store protocol and concrete** (delegating HTTP details to `ios-networking.md`, or persistence to `coredata-schema-designer.md`).
5. **Generate the service**: concrete implementing the protocol, depending only on client/store protocols, holding the domain rules.
6. **Generate the ViewModel**: `@MainActor @Observable`, initializer-injected service protocol, explicit `ViewState`.
7. **Generate the View** (SwiftUI by default; UIKit ViewController if the codebase demands) rendering the `ViewState` exhaustively — see `swiftui-patterns.md`.
8. **Wire the composition root**: add the new concretes to `AppDependencies`, thread them to the view's construction site.
9. **Generate mocks + one ViewModel test** proving the loading/success/failure transitions — see `xctest-patterns.md`.
10. **Verify against the Quality Checklist** below; build and run the tests.

## Patterns

### Service protocol + concrete (the seam)

```swift
protocol UserServicing: Sendable {
    func fetchUser(id: UUID) async throws -> User
    func updateDisplayName(_ name: String, for id: UUID) async throws -> User
}

struct UserService: UserServicing {
    private let client: any APIClienting        // protocol from the client layer

    init(client: any APIClienting) { self.client = client }

    func fetchUser(id: UUID) async throws -> User {
        try await client.send(GetUser(id: id))  // DTO→domain mapping happens in the client
    }

    func updateDisplayName(_ name: String, for id: UUID) async throws -> User {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw UserError.invalidDisplayName   // domain rule lives HERE, not in the ViewModel
        }
        return try await client.send(UpdateUser(id: id, name: name))
    }
}
```

### ViewModel: @Observable, @MainActor, explicit state

```swift
@MainActor @Observable
final class UserProfileViewModel {
    enum ViewState { case idle, loading, loaded(User), failed(message: String) }

    private(set) var state: ViewState = .idle
    private let service: any UserServicing
    private let userID: UUID

    init(service: any UserServicing, userID: UUID) {
        self.service = service
        self.userID = userID
    }

    func load() async {
        state = .loading
        do { state = .loaded(try await service.fetchUser(id: userID)) }
        catch { state = .failed(message: Self.message(for: error)) }
    }
}
```

### View rendering state exhaustively

```swift
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel

    init(viewModel: UserProfileViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        Group {
            switch viewModel.state {           // exhaustive — no default:
            case .idle, .loading: ProgressView()
            case .loaded(let user): ProfileContent(user: user)
            case .failed(let message): RetryView(message: message) {
                Task { await viewModel.load() }
            }
            }
        }
        .task { await viewModel.load() }       // tied to view lifetime ⇒ auto-cancel
    }
}
```

### Composition root + Environment transport

```swift
@MainActor @Observable
final class AppDependencies {
    let userService: any UserServicing
    // The ONLY place concretes are chosen:
    init() {
        let client = APIClient(session: .init(configuration: .default), baseURL: AppConfig.apiURL)
        self.userService = UserService(client: client)
    }
}

@main struct MyApp: App {
    @State private var dependencies = AppDependencies()
    var body: some Scene {
        WindowGroup {
            RootView().environment(dependencies)   // transport only — ViewModels still get inits
        }
    }
}

// At a construction site:
// UserProfileView(viewModel: .init(service: dependencies.userService, userID: id))
```

### Hand-written mock + test

```swift
final class MockUserService: UserServicing, @unchecked Sendable {
    var fetchUserResult: Result<User, Error> = .failure(TestError.unstubbed)
    private(set) var fetchUserCalls: [UUID] = []

    func fetchUser(id: UUID) async throws -> User {
        fetchUserCalls.append(id)
        return try fetchUserResult.get()
    }
    func updateDisplayName(_ name: String, for id: UUID) async throws -> User {
        try fetchUserResult.get()
    }
}

@MainActor
func testLoadSuccessTransitionsToLoaded() async {
    let mock = MockUserService()
    mock.fetchUserResult = .success(.fixture(name: "Ada"))
    let vm = UserProfileViewModel(service: mock, userID: .init())

    await vm.load()

    guard case .loaded(let user) = vm.state else { return XCTFail("expected .loaded") }
    XCTAssertEqual(user.name, "Ada")
    XCTAssertEqual(mock.fetchUserCalls.count, 1)
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| ViewModel untestable without a server | View or ViewModel constructs `URLSession`/concrete client internally | Inject the service protocol through `init`; concretes only in the composition root |
| Tests pass, app broken (or vice versa) | Mocks at the wrong layer — mocking the client to test the service *and* the service to test the VM, with no contract test between | Mock exactly one layer down; cover the client itself with URLProtocol tests (`ios-networking.md`) |
| `Foo.shared` sprinkled through ViewModels | "DI is too much ceremony" | Keep one instance in `AppDependencies`; pass it in — same lifetime, visible dependency |
| Massive ViewModel with business rules, formatting, caching | Service layer skipped; VM became the junk drawer | Extract domain rules to the service; VM keeps only intent→call and result→state translation |
| Backend renames a JSON field, 14 files change | DTOs used as domain models throughout | Map DTO→domain at the client boundary; only the mapping changes |
| Crash: "Publishing changes from background thread" / UI updates lost | ViewModel not `@MainActor`, state set from a background continuation | Annotate the ViewModel class `@MainActor`; services stay nonisolated |
| Spinner forever after navigating away and back | Load task detached from view lifetime, state machine never reset | Use `.task {}` (auto-cancels), make `load()` idempotent from `.failed`/`.idle` |
| Protocol with 15 methods, every mock 100 lines | One mega-service per app instead of per domain | Split by domain; ViewModels compose multiple small services |
| New feature uses a different architecture than the rest | Generator ignored existing conventions | Workflow step 1: read first; extend the incumbent pattern |
| `default:` in the View's state switch hides new states | Non-exhaustive rendering | Switch exhaustively over `ViewState`; adding a case must break the build |

## Quality Checklist

- [ ] No layer skipped: Views never import the client/store layer; ViewModels never touch URLSession/Core Data types
- [ ] Every ViewModel dependency is a protocol received via `init` — zero `.shared` reads in business code
- [ ] Concrete types constructed in exactly one composition root file
- [ ] ViewModels are `@MainActor @Observable` (or `ObservableObject` pre-iOS 17, matching the codebase); services/clients are `Sendable`
- [ ] Domain rules live in services — ViewModels contain only state translation
- [ ] DTOs (Codable wire types) are confined to the client layer with explicit domain mapping
- [ ] Every protocol ships with a mock that records calls and stubs results (hand-written by default, or via the codebase's existing generator)
- [ ] At least one ViewModel test covers loading → loaded and loading → failed transitions
- [ ] View state is an enum rendered with an exhaustive switch (no `default:`)
- [ ] Async work is tied to view lifetime (`.task`) or explicitly cancelled
- [ ] Service protocols are domain-shaped (verbs of the business), not transport-shaped
- [ ] The new code matches the app's existing architecture and naming — no parallel second style
