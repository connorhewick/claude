---
name: port-ios-to-web
description: >
  Port an iOS app to an equivalent web experience. Use when the user asks to
  "port this iOS app to the web", "build a web version of my iPhone/iPad app",
  "convert this Xcode project to a web app", or supplies iOS inputs — either
  source (SwiftUI/UIKit files, `.xcodeproj`, `.xcworkspace`, `Package.swift`)
  for a high-fidelity port, or screenshots / App Store images / screen
  recordings for a visual-approximation port. Inventories screens,
  navigation, components, styling, state, and data flow; interviews the user
  on stack and fidelity trade-offs; produces a port plan; then scaffolds the
  web app and drives the port screen-by-screen. Do NOT trigger for greenfield
  web work with no iOS reference, native cross-platform ports (iOS →
  Android), or one-off UI snippet conversions.
argument-hint: [path-to-ios-project]
---

Turn an iOS codebase into a web app that reproduces the same user experience —
same screens, same flows, same feel — using web-native primitives. The value
of this skill is in the *iOS-to-web translation*: mapping SwiftUI/UIKit
constructs to their nearest web equivalents, and surfacing the fidelity
trade-offs where no equivalent exists.

Runs inline in the main session (not a subagent) because the interview and
walkthrough need live `AskUserQuestion` round-trips.

## Preconditions

- Determine the **input mode** before anything else:
  - **Source mode** — an iOS codebase is accessible from the workspace
    (Swift/Obj-C files, `.xcodeproj`, `.xcworkspace`, `Package.swift`). This
    is the high-fidelity path — behavior, state, and data flow can be ported
    accurately.
  - **Screenshot mode** — only screenshots, App Store images, screen
    recordings, or a Figma export are available. This is a
    *visual-approximation* port: layout, look, and inferred flows only.
    Behavior, state, and data are guesses. Tell the user this upfront so
    they don't expect source-parity, and route every behavior-shaped
    question to **Open questions** in the plan.
- Confirm licensing / permission to port before starting (the user owns the
  code or screenshots, or has authorization). Do not port third-party apps
  without it.

## 1 — Inventory the iOS project

**In source mode**, read enough of the source to answer the items below.
**In screenshot mode**, catalog what each image shows (screen name, visible
elements, apparent state) and infer navigation from repeated chrome (tab
bars, nav bars); every inference becomes an Open question, not a decision.

Read enough of the source to answer these, and write the answers into the
port plan (§4) rather than holding them in your head:

Then, in source mode, cover:

- **Language & UI framework:** Swift vs. Obj-C; SwiftUI, UIKit, or mixed.
- **Architecture:** MVC, MVVM, TCA, Redux/Swift, plain `@Observable`.
- **Navigation:** `NavigationStack` / `UINavigationController`, tab bars,
  sheets/`.sheet`, `UIModalPresentationStyle`, deep links.
- **Screens & flows:** every screen, its entry points, and the interactions
  that define it (a swipe-to-delete row is not the same as a tap-to-delete).
- **State & data:** `@State`/`@Observable`/`@EnvironmentObject`, Combine
  publishers, Core Data / SwiftData, `URLSession` calls, GraphQL/REST
  endpoints.
- **Design system:** `Assets.xcassets` (colors, images), custom fonts, SF
  Symbols usage, light/dark appearance, dynamic type.
- **Platform features with no direct web equivalent:** Push (APNs), Haptics,
  HealthKit, Core Location background modes, Camera/Photo library, Keychain,
  Sign in with Apple, App Clips, WidgetKit. Flag each — they need a stubbed
  or degraded web behavior.
- **Dependencies:** SwiftPM / CocoaPods / Carthage manifest.

## 2 — Interview for scope, fidelity, and stack

Batch with `AskUserQuestion` (≤4 per call). Only ask what's genuinely
undecided; skip questions the source or prior context already answers.

- **Scope:** All screens, or an MVP subset (which)? Parity with current
  release, or drop deprecated flows?
- **Fidelity target:** Pixel-perfect iOS look (bottom tab bar, iOS-style
  navigation transitions, SF-like typography) vs. "native web feel" that
  respects browser conventions.
- **Viewport:** Mobile-only (iOS-shaped canvas), desktop-first, or fully
  responsive with a mobile breakpoint that mirrors the iOS layout.
- **Web stack:** framework (recommend React + Vite, or Next.js if SSR/SEO
  matter), styling (recommend Tailwind for tokenizable design), state
  (Zustand / Redux Toolkit / framework-native), routing (framework-native).
- **Backend:** reuse the existing API as-is, add a thin BFF, or stub with
  fixtures for the port.
- **Native-only features:** for each item flagged in §1, pick a web
  behavior — closest equivalent (`Notification API`, `navigator.vibrate`,
  `MediaDevices`, Web Push / VAPID), degraded (hidden / disabled with
  explanation), or deferred (open question).

Record deferred answers under **Open questions** in the plan rather than
guessing.

## 3 — Map iOS constructs to web equivalents

Build a translation table in the port plan; extend as you find more. Starting
points:

| iOS construct | Web equivalent |
| --- | --- |
| `UIViewController` / SwiftUI screen `View` | Route / page component |
| `NavigationStack` push/pop | Router push/back + animated transitions |
| `TabView` / `UITabBarController` | Bottom tab bar (mobile) / side nav (desktop) |
| `.sheet` / `UIModalPresentationStyle` | Modal / dialog / bottom sheet |
| `List` / `UITableView` | Virtualized list (`@tanstack/react-virtual`) |
| `LazyVGrid` / `UICollectionView` | CSS Grid / masonry |
| `@State`, `@Observable`, `@EnvironmentObject` | Local state / store / context |
| `Combine.Publisher` | RxJS observable or async iterator |
| `Assets.xcassets` colors | CSS custom properties / theme tokens |
| SF Symbols | Lucide/Heroicons; optionally SF Symbols web font under Apple's license |
| System font | `-apple-system, BlinkMacSystemFont, "SF Pro Text", …` stack |
| Dynamic Type | `rem`-based sizing + user-scaling media queries |
| Light/Dark appearance | `prefers-color-scheme` + `[data-theme]` override |
| Core Data / SwiftData | IndexedDB (Dexie) for local; server DB otherwise |
| `URLSession` | `fetch` / TanStack Query for caching |
| Push (APNs) | Web Push (VAPID) — flag Safari iOS PWA-only |
| Haptics | `navigator.vibrate` — degraded, no Taptic patterns |
| Sign in with Apple | Sign in with Apple JS (web flow) |
| Keychain | `Credential Management API` where supported; server session otherwise |

## 4 — Write the port plan

Save to `docs/port/NNNN-slug.md` (next unused four-digit number in
`docs/port/`, start at `0001`). Keep sections in this order:

```markdown
# NNNN. Port <app name> to web

Date: <YYYY-MM-DD> · Status: Draft

## Overview
<Source iOS project, target web experience, scope.>

## Screen inventory
<Every screen, its entry points, and defining interactions.>

## Translation table
<iOS-to-web mappings that apply to this app, extended from §3.>

## Stack
<Framework, styling, state, routing, backend approach.>

## Fidelity & non-goals
<Fidelity target; what's intentionally not being ported (deprecated flows,
native-only features stubbed or dropped).>

## Milestones
1. Foundation — design tokens, layout primitives, navigation shell.
2. Auth & data — sessions, API client, seed fixtures.
3. Screens — grouped by flow, in the order a new user hits them.
4. Polish — animations, empty/loading/error states, dark mode, a11y.

## Open questions
<Deferred decisions to settle before or during implementation.>
```

Present the plan and let the user amend before scaffolding. Plans are cheap
to change; scaffolds are not.

## 5 — Scaffold the web app

Only after plan approval. Default web root: `web/` (or the user's chosen
path). Steps:

- Initialize the chosen framework and install dependencies.
- Port design tokens from `Assets.xcassets`: colors → CSS variables (light +
  dark), fonts → `@font-face` or system stack, icons → chosen library.
- Build the navigation shell (tab bar / stack analog) with no screens yet.
- Wire the theme to `prefers-color-scheme` and a manual toggle.

## 6 — Port screens in milestone order

For each screen: read the SwiftUI/UIKit source, translate it into the chosen
framework using the §3 table, wire navigation and state, then drive it in a
browser (`/run` skill or the project's dev server) and compare against the
iOS build. Do not batch a whole milestone before verifying — one screen, one
verification.

Where a native affordance has no equivalent (haptics, Taptic patterns, iOS
share sheet), pick the degraded behavior from §2 and note the delta.

## 7 — Verify & walkthrough

- Run whatever this project uses to verify changes (tests, lint, build) for
  every stage relevant to the change.
- Do the walkthrough + interview from `CLAUDE.md`: narrate the port in review
  order (foundation → shell → screens), reference `file:line`, ask about
  anything ambiguous, and incorporate the answers before opening a PR.

Not done until the plan's milestones are hit, the project's own checks
pass, CI is green, and a human has approved.
