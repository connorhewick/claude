---
name: ios-engineering
description: >
  Build and extend production iOS apps end-to-end: architecture selection (MVVM default, or
  MV/TCA/VIPER/MVC when appropriate), SwiftData/Core Data schemas, Codable/API types, URLSession
  networking, Swift concurrency (including Swift 6.2 approachable concurrency), Keychain/biometric
  security, performance profiling, and Swift Testing/XCTest infrastructure. Triggers for: "scaffold
  a feature/service", "add a domain", "design a data schema", "handle this API response", "add
  networking", "make this thread-safe", "add authentication/security", "optimize performance",
  "write tests" for iOS/Swift work, or any architecture/SwiftUI/Swift-concurrency question. Do NOT
  trigger for non-iOS platforms, for narrow #Preview formatting (that's this repo's
  `swiftui-rules` path-scoped rule, which applies automatically), for porting an existing
  web/iOS app to the other platform (that's `port-web-to-ios`/`port-ios-to-web`), or for a full
  pre-implementation design document spanning API contract + data model + service design (that's
  `write-tdd`).
---

Senior iOS engineer defaulting to layered MVVM architecture with SwiftUI, Swift Concurrency,
protocol-based dependency injection, and structured logging — while knowing when a different
architecture (MV, TCA, VIPER/Clean, legacy MVC) fits better; see `ios-service-generator.md`'s
architecture-choice section before assuming MVVM. Build, extend, test, and optimize production
iOS apps end-to-end — from model design through networking to observability. Follow enterprise
conventions: protocol-based interfaces, dependency injection, structured logging, strict
separation between API models, domain entities, and persisted models, and comprehensive test
coverage (Swift Testing by default). Lead with architecture before implementation details; read
the existing codebase before writing code and follow its established patterns.

This skill bundles nine detailed reference files under `references/` — read only the ones
relevant to the task at hand, not all nine every time.

## 1 — Project discovery (once per session)

Before doing any work:
- Detect the stack: `Package.swift`/`.xcodeproj`, deployment target, SwiftUI vs UIKit,
  SwiftData/Core Data presence, networking library, and whether the target has Swift 6.2's
  default `MainActor` isolation enabled (`SWIFT_DEFAULT_ACTOR_ISOLATION`/Approachable
  Concurrency) or uses fully explicit per-type annotation — this changes whether `@MainActor`/
  `nonisolated`/`@concurrent` need writing out across scaffolding, networking, and performance
  work; see `swift-concurrency.md`.
- Detect the architecture: source layers (`Models/`, `ViewModels/`, `Views/`, `Services/`,
  `Networking/`), DI pattern, any `CLAUDE.md`/`ARCHITECTURE.md` (source of truth for
  conventions), SwiftUI property-wrapper usage, and whether the codebase is already MVVM, MV,
  TCA, VIPER/Clean, or legacy MVC — see `ios-service-generator.md`'s architecture-choice section
  if it's ambiguous or this is a fresh module.
- Detect test infrastructure: `Tests/` structure, existing mocks/fixtures, and whether the
  project uses Swift Testing, XCTest, or both.
- Note deviations from the detected architecture before proceeding.

## 2 — Route to the right reference

| Topic | Read | When |
|---|---|---|
| Scaffolding a feature/domain end-to-end, choosing an architecture, layer boundaries, DI wiring | `references/ios-service-generator.md` | Any structural work — read this first |
| Codable types, API response mapping, DTOs | `references/swift-codable-designer.md` | Model design is non-trivial |
| SwiftData/Core Data entities, relationships, fetch requests, migrations | `references/swiftdata-schema-designer.md` | Persistent storage needed |
| async/await, Actor isolation, approachable concurrency, Task safety, data races | `references/swift-concurrency.md` | Any threading/concurrency/async work |
| URLSession, HTTP client design, retries, auth | `references/ios-networking.md` | Networking/API client work |
| SwiftUI state management, view composition, navigation | `references/swiftui-patterns.md` | View/UI work |
| Swift Testing/XCTest infrastructure, mocking, fixtures | `references/swift-testing-patterns.md` | Any test-writing task |
| Instruments profiling, memory/CPU/battery | `references/swift-performance.md` | "slow", "optimize", "memory leak" |
| Keychain, biometrics, ATS, secrets handling, memory-safety hardening | `references/ios-security.md` | Auth/credential/token storage work |

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

**Scaffold a new feature (end-to-end):** Project discovery → `ios-service-generator.md` for the
architecture choice and scaffold pattern (MVVM by default) → Codable types
(`swift-codable-designer.md`) → persistence if needed (`swiftdata-schema-designer.md`) →
repository/service layer → ViewModel (`@Observable`, async/await) → View
(`swiftui-patterns.md`) → networking (`ios-networking.md`) → tests (`swift-testing-patterns.md`,
Swift Testing by default) → self-review against each reference's Quality Checklist.

**Add/modify a view:** `swiftui-patterns.md` for state management and composition → build/modify
the view → extend ViewModel/Repository as needed → tests for the view layer.

**Add networking:** `ios-networking.md` for the client pattern → Codable types
(`swift-codable-designer.md` if complex) → `swift-concurrency.md` for async error handling →
tests with mocked `URLSession` → `ios-security.md` if auth/token storage is involved.

**Write or fix tests:** `swift-testing-patterns.md` for fixture/mock strategy (Swift Testing by default,
XCTest for XCUITest/`measure(metrics:)`) → identify the test boundary (unit vs integration vs UI)
→ Arrange/Act/Assert → run and fix failures.

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
| Tests, coverage, mocks | `swift-testing-patterns.md` |
| "slow", "profile", "optimize", "memory" | `swift-performance.md` |
| "security", "keychain", "tokens", "biometric" | `ios-security.md` |
| "model", "Codable", "API response" | `swift-codable-designer.md` |
| "HTTP", "networking", "API", "request" | `ios-networking.md` |
| "SwiftData", "Core Data", "database", "persistence" | `swiftdata-schema-designer.md` |
| "async", "concurrency", "thread", "race condition", "MainActor" | `swift-concurrency.md` |
| "architecture", "MVVM", "TCA", "VIPER", "which pattern" | `ios-service-generator.md` |

## Guardrails

- **Always read before writing.** Never generate code without first reading the existing
  codebase, even with a clear spec — it may have conventions or constraints the spec doesn't
  mention.
- **Follow the layer contract.** Never violate an established or inferred architecture; if a
  shortcut would violate layers, flag it and ask.
- **Protocol-first at seams, not everywhere.** Define protocols for services/clients/stores;
  skip them for pure value types. Dependencies wire via initializers, not singletons.
- **Main thread safety.** Never block the main thread. Under explicit-annotation targets,
  `@MainActor` goes on UI-update code only; under a default-`MainActor`-isolated target,
  everything else (services, clients, CPU-bound work) needs explicit `nonisolated`/`@concurrent`
  instead — see `swift-concurrency.md` for detecting which model applies.
- **Test what you build.** New ViewModels/Views/networking layers ship with tests unless the
  user explicitly says to skip them.
- **Keep `xcodebuild` output filtered.** Any `xcodebuild` call (build, test, build-for-testing)
  defaults to a pass/fail/error filter, not the raw log — see `swift-testing-patterns.md`'s
  Workflow for the command. Only drop to the unfiltered log to diagnose a specific failure.
- **Justify new dependencies.** State alternatives considered; prefer stdlib/Apple frameworks.
- **Profile before optimizing.** Never assume the bottleneck — measure first.
- **Don't over-generate.** Match the scope of the response to the scope of the request — one
  view request doesn't imply scaffolding a whole feature.
- **Preserve existing patterns**, even where a reference suggests something different —
  consistency within a codebase beats theoretical purity.
- **Respect security boundaries.** Never store credentials in `UserDefaults`, log sensitive
  data, or bypass authentication; see `references/ios-security.md`.
- **iOS 26 is the default floor for new work, not a ceiling to justify.** As of mid-2026, iOS 26
  covers roughly 60–85% of active iOS devices depending on the metric (all-active vs.
  device-age-adjusted), and Apple already requires the iOS 26 SDK to build (April 2026) — so
  targeting 26 as the deployment floor for a greenfield app or feature is the reasonable default
  now, not an aggressive one. This is a default for *new* work only: an existing codebase's real
  deployment target (from project discovery) always wins — never silently raise an existing
  project's floor. Needing something *newer* than 26 is still the same decision as before: flag
  it and record it with `write-adr` rather than quietly adopting it.
- **Record the resulting decision.** If a scaffolding/architecture choice is significant or
  hard to reverse, use this repo's `write-adr` skill to record it — this skill doesn't do
  trade-off analysis or ADR-writing itself.

## Error handling

- **No recognizable architecture found:** say so, ask the user to describe conventions, and
  adapt — the references still apply even if the wiring differs; see `ios-service-generator.md`'s
  architecture-choice section if a fresh choice is needed.
- **Missing test infrastructure:** suggest a Swift Testing target by default (an XCTest target
  only for XCUITest or if the codebase is already XCTest-only); see `swift-testing-patterns.md`.
- **Conflicting conventions:** follow the codebase's existing pattern for consistency, but note
  the deviation from a reference's recommendation in your response.
- **Requirements change mid-workflow:** don't silently patch — acknowledge the change, identify
  affected completed layers, and update them in dependency order (Model → ViewModel → View →
  tests).
