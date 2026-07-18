---
name: port-web-to-ios
description: >
  Port a web app to an equivalent iOS experience. Use when the user asks to
  "port this web app to iOS", "build an iOS version of my website", "wrap this
  web app as an iPhone app", "convert this React/Vue/Svelte app to SwiftUI",
  or supplies web inputs — either source (a `package.json`-rooted web project,
  React/Vue/Svelte/Angular/vanilla HTML+CSS+JS) for a high-fidelity port, or
  screenshots / a live URL / a Figma export for a visual-approximation port.
  Inventories routes, components, styling, state, and data flow; interviews
  the user on the native-vs-hybrid decision, iOS UI framework, and fidelity
  trade-offs; produces a port plan; then scaffolds the Xcode project and
  drives the port screen-by-screen. Do NOT trigger for greenfield iOS work
  with no web reference, native cross-platform ports (web → Android without
  iOS), or one-off UI snippet conversions.
argument-hint: [path-to-web-project-or-url]
---

Turn a web codebase into an iOS app that reproduces the same user experience
— same screens, same flows, same feel — using iOS-native primitives (or a
hybrid wrapper when that's the right call). The value of this skill is in
the *web-to-iOS translation*: mapping HTML/CSS/JS constructs to their nearest
SwiftUI/UIKit equivalents, reshaping page-based navigation into iOS's
push/pop/sheet model, and surfacing the fidelity trade-offs where web idioms
fight iOS Human Interface Guidelines.

Runs inline in the main session (not a subagent) because the interview and
walkthrough need live `AskUserQuestion` round-trips.

## Preconditions

- Determine the **input mode** before anything else:
  - **Source mode** — a web codebase is accessible from the workspace
    (`package.json`, framework config, source files). This is the
    high-fidelity path — behavior, state, and data flow can be ported
    accurately.
  - **Screenshot / live-URL mode** — only screenshots, a public URL, or a
    Figma export is available. This is a *visual-approximation* port:
    layout, look, and inferred flows only. Behavior, state, and data are
    guesses. Tell the user this upfront so they don't expect source-parity,
    and route every behavior-shaped question to **Open questions** in the
    plan.
- Confirm licensing / permission to port before starting (the user owns the
  code or screenshots, or has authorization). Do not port third-party apps
  without it.
- macOS + Xcode are required to build and run an iOS app. If the session
  environment lacks them, say so — you can still write the plan, scaffold,
  and source, but final `xcodebuild` / simulator verification must happen on
  the user's Mac.

## 1 — Inventory the web project

**In source mode**, read enough of the source to answer the items below.
**In screenshot / URL mode**, catalog what each image or route shows (screen
name, visible elements, apparent state) and infer navigation from repeated
chrome (headers, tab bars, side nav); every inference becomes an Open
question, not a decision.

Then, in source mode, cover:

- **Framework & language:** React / Vue / Svelte / Angular / SolidJS / vanilla;
  TypeScript vs. JavaScript; Vite / Next.js / Nuxt / SvelteKit / Remix.
- **Routing:** file-based (Next/Nuxt/SvelteKit), React Router, Vue Router,
  hash routes; nested layouts; dynamic segments; auth guards.
- **Component & design system:** shadcn/ui, Material UI, Chakra, Ant Design,
  Radix, headless-only, or bespoke. Global CSS, CSS Modules, Tailwind,
  styled-components, vanilla-extract.
- **State & data:** Redux / Zustand / Jotai / Pinia / Svelte stores /
  Context; TanStack Query / SWR / Apollo; WebSockets / SSE; forms library
  (react-hook-form, Formik, VeeValidate).
- **Backend surface:** REST / GraphQL endpoints, auth (JWT, session cookies,
  OAuth providers, Sign in with Apple, magic links), file uploads, realtime.
- **Design tokens:** colors (light + dark), typography scale, spacing scale,
  icon library (Lucide / Heroicons / Font Awesome / custom SVGs), custom web
  fonts.
- **Web-only features with no native equivalent:** service workers, IndexedDB
  usage, browser history stack, `window.open`, `<iframe>`, complex CSS
  effects (backdrop-filter chains, `mix-blend-mode`), WebGL/canvas, `<video>`
  with custom controls, drag-and-drop between browser windows, extensions.
  Flag each — they need a rebuilt, degraded, or dropped native behavior.
- **Dependencies:** `package.json` production deps (many won't have iOS
  equivalents and drive rewrite decisions).

## 2 — Interview for approach, stack, and fidelity

Batch with `AskUserQuestion` (≤4 per call). Only ask what's genuinely
undecided; skip questions the source or prior context already answers.

- **Native vs. hybrid approach** — the biggest decision, ask first:
  - **Native SwiftUI** (recommended default) — highest fidelity to iOS, best
    performance, largest rewrite. Every screen re-implemented in Swift.
  - **Native UIKit** — pick only if the target iOS version predates SwiftUI
    or the design fights SwiftUI's layout model.
  - **Hybrid via Capacitor** — wrap the existing web app in a `WKWebView`
    with native plugins for camera / push / haptics / share. Fastest to
    ship, weakest iOS feel; the web codebase stays the source of truth.
  - **React Native** — pick only if the web app is already React and the
    user wants a shared component layer; note that RN is not "port to iOS,"
    it's "rewrite for iOS + Android with a shared framework."
- **Target iOS version:** iOS 17+ unlocks `@Observable`, `NavigationStack`
  affordances, `.sheet` detents. iOS 16 / 15 constrain the toolset.
- **Fidelity target:** web-parity (identical layout, web idioms preserved)
  vs. **HIG-native feel** (recommended — respect iOS conventions:
  `NavigationStack`, `.sheet`, `TabView`, SF Symbols, system fonts, native
  gestures). HIG-native usually means *dropping* some web layouts, not
  translating them.
- **Design tokens:** translate the web design system into an iOS asset
  catalog + `Color`/`Font` extensions, or adopt iOS system defaults and only
  keep brand accents.
- **Backend:** reuse the existing API as-is (usually the answer), add a
  thin iOS-specific BFF, or stub with fixtures for the port.
- **Native features to add** (things the web version couldn't do): Haptics,
  Sign in with Apple, biometric unlock (`LAContext`), Share sheet
  (`UIActivityViewController`), Push (APNs), Widgets, Live Activities,
  App Clips. Ask per item; each is optional scope.

Record deferred answers under **Open questions** in the plan rather than
guessing.

## 3 — Map web constructs to iOS equivalents

Build a translation table in the port plan; extend as you find more.
Starting points (native-SwiftUI column; skip in hybrid mode):

| Web construct | iOS (SwiftUI) equivalent |
| --- | --- |
| Route / page component | Screen `View` inside `NavigationStack` |
| Router `push` / `back` | `NavigationLink` / `dismiss()` |
| Modal / dialog | `.sheet` |
| Bottom sheet | `.sheet` with `.presentationDetents([.medium, .large])` |
| Tab bar / side nav | `TabView` |
| Virtualized list (`@tanstack/react-virtual`) | `List` / `LazyVStack` in `ScrollView` |
| CSS Grid | `LazyVGrid` / `Grid` |
| Flexbox | `HStack` / `VStack` / `Spacer` / `.frame` |
| `useState` | `@State` |
| Context / Zustand / Redux store | `@Observable` model in `@Environment` |
| TanStack Query / SWR | `URLSession` + `async/await` + a lightweight cache |
| Form library (react-hook-form) | `Form` + `@State` + custom validation |
| CSS custom properties (light + dark) | `Assets.xcassets` color sets |
| Icon library (Lucide / Heroicons) | SF Symbols (`Image(systemName:)`) |
| Web fonts | Bundled `.ttf` / `.otf` + `UIAppFonts` in `Info.plist` |
| System font stack | `.system(.body, design: .default)` |
| `prefers-color-scheme` | `@Environment(\.colorScheme)` |
| `localStorage` | `UserDefaults` (non-sensitive) / Keychain (sensitive) |
| IndexedDB | SwiftData (iOS 17+) or Core Data |
| `fetch` streaming / SSE | `URLSession.bytes` |
| WebSockets | `URLSessionWebSocketTask` |
| Web Push | APNs (`UNUserNotificationCenter`) |
| `navigator.vibrate` | `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` |
| `navigator.share` | `UIActivityViewController` (`ShareLink` in SwiftUI) |
| OAuth redirect flow | `ASWebAuthenticationSession` |
| Sign in with Apple JS | Sign in with Apple (`ASAuthorizationAppleIDProvider`) |
| Deep links (`window.location`) | Universal Links + `.onOpenURL` |
| `<video>` custom controls | `AVPlayer` + `VideoPlayer` |
| Camera / MediaDevices | `AVFoundation` + `UIImagePickerController` / `PhotosPicker` |
| Drag-and-drop | `.draggable` / `.dropDestination` |
| Service worker offline cache | Native URL cache + on-disk store |

## 4 — Write the port plan

Save to `docs/port/NNNN-slug.md` (next unused four-digit number in
`docs/port/`, start at `0001`). Keep sections in this order:

```markdown
# NNNN. Port <app name> to iOS

Date: <YYYY-MM-DD> · Status: Draft

## Overview
<Source web project, target iOS experience, scope.>

## Screen inventory
<Every screen / route, its entry points, and defining interactions.>

## Translation table
<Web-to-iOS mappings that apply to this app, extended from §3.>

## Approach & stack
<Native SwiftUI vs. UIKit vs. Capacitor hybrid vs. React Native; target
iOS version; design-token strategy; backend reuse.>

## Fidelity & non-goals
<Fidelity target (web-parity vs. HIG-native); web-only features
intentionally not being ported (service workers, complex CSS effects,
iframes, browser-extension surfaces).>

## Milestones
1. Foundation — Xcode project, design tokens (Assets.xcassets, fonts),
   navigation shell (`NavigationStack` / `TabView`).
2. Auth & data — API client, session/token storage, seed fixtures.
3. Screens — grouped by flow, in the order a new user hits them.
4. iOS polish — haptics, share, empty/loading/error states, dark mode,
   Dynamic Type, VoiceOver, safe-area handling.

## Open questions
<Deferred decisions to settle before or during implementation.>
```

Present the plan and let the user amend before scaffolding. Plans are cheap
to change; Xcode projects are not.

## 5 — Scaffold the iOS app

Only after plan approval. Default location: `ios/` (or the user's chosen
path). Steps depend on the chosen approach:

- **Native SwiftUI / UIKit:** create the Xcode project (`xcodebuild
  -create-xcworkspace` or an `XcodeGen` `project.yml`), set bundle id,
  minimum deployment target, and signing team placeholder. Add design
  tokens: colors → `Assets.xcassets` color sets (Any + Dark), fonts →
  bundled files + `UIAppFonts` entry, icons → SF Symbols mapping. Build the
  navigation shell with no screens yet.
- **Hybrid (Capacitor):** `npx cap add ios` inside the existing web repo;
  configure `Info.plist` (`NSAppTransportSecurity`, camera / photo library
  usage strings as needed); add the plugins the interview picked (Haptics,
  Push, Share, Camera).

Wire theming to `@Environment(\.colorScheme)` and a manual toggle so light
and dark parity is testable from day one.

## 6 — Port screens in milestone order

For each screen: read the web source (JSX/Vue SFC/Svelte component),
translate it into SwiftUI using the §3 table, wire navigation and state,
then drive it in the iOS Simulator (`/run` skill or `xcrun simctl` +
`xcodebuild`) and compare against the web build. Do not batch a whole
milestone before verifying — one screen, one verification.

Where a web idiom fights iOS (multi-column dense tables, hover-only menus,
right-click context menus, browser back-button reliance), pick the HIG
alternative from §2's fidelity choice and note the delta.

## 7 — Verify & walkthrough

- Run whatever this project uses to verify changes (tests, lint, build) for
  every stage relevant to the change.
- On the user's Mac (or a hosted Mac runner): `xcodebuild build` must
  succeed, and the app must launch in the Simulator. If the session
  environment can't run Xcode, hand off with clear reproduction steps
  instead of claiming the port is done.
- Do the walkthrough + interview from `CLAUDE.md`: narrate the port in
  review order (foundation → shell → screens), reference `file:line`, ask
  about anything ambiguous, and incorporate the answers before opening a PR.

Not done until the plan's milestones are hit, the project's own checks
pass, CI is green, and a human has approved.
