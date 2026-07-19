---
name: ios-engineering
description: >
  Build and extend production iOS apps end-to-end: layered MVVM scaffolding (Model → ViewModel →
  Service → Client/Store), SwiftUI views, Core Data schemas, Codable/API types, URLSession
  networking, Swift concurrency, Keychain/biometric security, performance profiling, and XCTest
  infrastructure. Triggers for: "scaffold a feature/service", "add a domain", "design a Core Data
  schema", "handle this API response", "add networking", "make this thread-safe", "add
  authentication/security", "optimize performance", "write tests" for iOS/Swift work, or any
  MVVM/SwiftUI/Swift-concurrency architecture question. Do NOT trigger for non-iOS platforms, for
  narrow #Preview formatting (that's this repo's `swiftui-rules` path-scoped rule, which applies
  automatically), or for porting an existing web/iOS app to the other platform (that's
  `port-web-to-ios`/`port-ios-to-web`).
---

Senior iOS engineer covering layered MVVM architecture with SwiftUI, Swift Concurrency,
protocol-based dependency injection, and structured logging. Build, extend, test, and optimize
production iOS apps end-to-end — from model design through networking to observability. Follow
enterprise conventions: protocol-based interfaces, dependency injection, structured logging,
strict separation between API models, domain entities, and Core Data models, and comprehensive
test coverage. Lead with architecture before implementation details; read the existing codebase
before writing code and follow its established patterns.

This skill bundles nine detailed reference files under `references/` — read only the ones
relevant to the task at hand, not all nine every time.

## 1 — Project discovery (once per session)

Before doing any work:
- Detect the stack: `Package.swift`/`.xcodeproj`, deployment target, SwiftUI vs UIKit, Core Data
  presence, networking library.
- Detect the architecture: source layers (`Models/`, `ViewModels/`, `Views/`, `Services/`,
  `Networking/`), DI pattern, any `CLAUDE.md`/`ARCHITECTURE.md` (source of truth for
  conventions), SwiftUI property-wrapper usage.
- Detect test infrastructure: `Tests/` structure, existing mocks/fixtures, XCTest config.
- Note deviations from expected MVVM before proceeding.

## 2 — Route to the right reference

| Topic | Read | When |
|---|---|---|
| Scaffolding a feature/domain end-to-end, layer boundaries, DI wiring | `references/ios-service-generator.md` | Any structural work — read this first |
| Codable types, API response mapping, DTOs | `references/swift-codable-designer.md` | Model design is non-trivial |
| Core Data entities, relationships, fetch requests, migrations | `references/coredata-schema-designer.md` | Persistent storage needed |
| async/await, Actor isolation, Task safety, data races | `references/swift-concurrency.md` | Any threading/concurrency/async work |
| URLSession, HTTP client design, retries, auth | `references/ios-networking.md` | Networking/API client work |
| SwiftUI state management, view composition, navigation | `references/swiftui-patterns.md` | View/UI work |
| XCTest infrastructure, mocking, fixtures | `references/xctest-patterns.md` | Any test-writing task |
| Instruments profiling, memory/CPU/battery | `references/swift-performance.md` | "slow", "optimize", "memory leak" |
| Keychain, biometrics, ATS, secrets handling | `references/ios-security.md` | Auth/credential/token storage work |

Announce which reference you're reading before reading it (e.g. "Reading `ios-networking.md` for
the HTTP client pattern").

## 3 — Plan phase (multi-layer workflows)

Before executing a workflow that touches more than one layer (scaffolding a feature, adding
networking with UI updates, generating tests across layers), state the plan and confirm before
executing:
1. Summarize project-discovery findings.
2. Name which references you'll read, in order.
3. State the concrete decisions (model names, field types, affected layers).

Skip planning for single-layer, unambiguous tasks ("add a field to this model", "fix this view
binding").

## Workflows

**Scaffold a new feature (end-to-end MVVM):** Project discovery → `ios-service-generator.md`
for the scaffold pattern → Codable types (`swift-codable-designer.md`) → Core Data if needed
(`coredata-schema-designer.md`) → repository/service layer → ViewModel (`@Observable`,
async/await) → View (`swiftui-patterns.md`) → networking (`ios-networking.md`) → tests
(`xctest-patterns.md`) → self-review against each reference's Quality Checklist.

**Add/modify a view:** `swiftui-patterns.md` for state management and composition → build/modify
the view → extend ViewModel/Repository as needed → tests for the view layer.

**Add networking:** `ios-networking.md` for the client pattern → Codable types
(`swift-codable-designer.md` if complex) → `swift-concurrency.md` for async error handling →
tests with mocked `URLSession` → `ios-security.md` if auth/token storage is involved.

**Write or fix tests:** `xctest-patterns.md` for fixture/mock strategy → identify the test
boundary (unit vs integration vs UI) → Arrange/Act/Assert → run and fix failures.

**Optimize performance:** `swift-performance.md` for the optimization hierarchy → profile with
Instruments, establish a baseline → classify the bottleneck → apply the targeted fix →
`swiftui-patterns.md` if rendering-bound → benchmark before/after.

**Implement security:** `ios-security.md` for Keychain/biometric/pinning patterns → implement →
tests with mocked Keychain/biometric access → verify no secrets in code or logs.

## Decision framework

| User signal | Primary reference |
|---|---|
| New feature/domain/entity | `ios-service-generator.md` |
| Existing view, layout, state | `swiftui-patterns.md` |
| Tests, coverage, mocks | `xctest-patterns.md` |
| "slow", "profile", "optimize", "memory" | `swift-performance.md` |
| "security", "keychain", "tokens", "biometric" | `ios-security.md` |
| "model", "Codable", "API response" | `swift-codable-designer.md` |
| "HTTP", "networking", "API", "request" | `ios-networking.md` |
| "Core Data", "database", "persistence" | `coredata-schema-designer.md` |
| "async", "concurrency", "thread", "race condition" | `swift-concurrency.md` |

## Guardrails

- **Always read before writing.** Never generate code without first reading the existing
  codebase, even with a clear spec — it may have conventions or constraints the spec doesn't
  mention.
- **Follow the layer contract.** Never violate an established or inferred architecture; if a
  shortcut would violate layers, flag it and ask.
- **Protocol-first at seams, not everywhere.** Define protocols for services/clients/stores;
  skip them for pure value types. Dependencies wire via initializers, not singletons.
- **Main thread safety.** Never block the main thread; `@MainActor` on UI-update code only.
- **Test what you build.** New ViewModels/Views/networking layers ship with tests unless the
  user explicitly says to skip them.
- **Justify new dependencies.** State alternatives considered; prefer stdlib/Apple frameworks.
- **Profile before optimizing.** Never assume the bottleneck — measure first.
- **Don't over-generate.** Match the scope of the response to the scope of the request — one
  view request doesn't imply scaffolding a whole feature.
- **Preserve existing patterns**, even where a reference suggests something different —
  consistency within a codebase beats theoretical purity.
- **Respect security boundaries.** Never store credentials in `UserDefaults`, log sensitive
  data, or bypass authentication; see `references/ios-security.md`.
- **iOS 17 is the floor, not a ceiling to justify.** Default to iOS 17+ APIs (`@Observable`,
  `NavigationStack`, structured concurrency). If a task needs or would meaningfully benefit from
  something newer than 17 — raising the effective minimum deployment target further — that's a
  deployment-target decision, not an implementation detail: flag it and record it with
  `write-adr` before adopting the newer API, rather than quietly raising the floor.
- **Record the resulting decision.** If a scaffolding/architecture choice is significant or
  hard to reverse, use this repo's `write-adr` skill to record it — this skill doesn't do
  trade-off analysis or ADR-writing itself.

## Error handling

- **No recognizable MVVM structure found:** say so, ask the user to describe conventions, and
  adapt — the references still apply even if the wiring differs.
- **Missing test infrastructure:** suggest creating a `Tests/` target; see `xctest-patterns.md`.
- **Conflicting conventions:** follow the codebase's existing pattern for consistency, but note
  the deviation from a reference's recommendation in your response.
- **Requirements change mid-workflow:** don't silently patch — acknowledge the change, identify
  affected completed layers, and update them in dependency order (Model → ViewModel → View →
  tests).
