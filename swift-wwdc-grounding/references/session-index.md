# WWDC session index — Swift and Apple-platform engineering

A curated topic→session map, verified against Apple's own catalog pages as of **July 2026**
(current cycle: **WWDC26**, Swift 6.3/6.4, Xcode 27).

**This index is a fast path, not a source.** It exists so a lookup usually costs zero searches.
It never substitutes for fetching the session — resolve the session here, then retrieve the
transcript and quote it. An entry missing from this index means "search Apple directly," never
"no such session exists."

Session URLs are `https://developer.apple.com/videos/play/wwdc<year>/<id>/`.

## Routing by topic

| Topic | Start here | Then |
|---|---|---|
| Swift language, new syntax/features | *What's new in Swift* — WWDC26 262 | WWDC25 245, WWDC24 10136 |
| Concurrency, actors, data races, `@MainActor` | *Embracing Swift concurrency* — WWDC25 268 | WWDC24 10169; WWDC25 270 (code-along), WWDC25 266 (SwiftUI) |
| Swift 6 migration, strict concurrency checking | *Migrate your app to Swift 6* — WWDC24 10169 | WWDC25 268 |
| SwiftUI, current cycle | *What's new in SwiftUI* — WWDC26 269 | WWDC25 256, WWDC24 10144, WWDC23 10148 |
| SwiftUI state / `@Observable` vs `ObservableObject` | *Discover Observation in SwiftUI* — WWDC23 10149 | WWDC25 266 |
| SwiftUI performance, view identity, re-render cost | *Demystify SwiftUI performance* — WWDC23 10160 | WWDC25 306, WWDC26 321 |
| SwiftUI scrolling, lazy stacks | *Dive into lazy stacks and scrolling with SwiftUI* — WWDC26 321 | WWDC25 306 |
| SwiftUI ↔ UIKit/AppKit interop | *Use SwiftUI with AppKit and UIKit* — WWDC26 272 | WWDC26 278, WWDC25 282 |
| SwiftData basics | *Meet SwiftData* — WWDC23 10187 | WWDC23 10196, WWDC26 275 (code-along) |
| SwiftData migration, schema evolution, inheritance | *SwiftData: Dive into inheritance and schema migration* — WWDC25 291 | WWDC26 274 |
| Testing (Swift Testing) | *Meet Swift Testing* — WWDC24 10179 | WWDC26 267 (migration), WWDC25 344 (UI automation) |
| Xcode, build, tooling | *What's new in Xcode 27* — WWDC26 258 | WWDC25 247, WWDC24 10135 |
| Performance / Instruments — responsiveness | *Profile, fix, and verify: Improve app responsiveness with Instruments* — WWDC26 268 | WWDC25 308 |
| Performance — memory, CPU, power | *Improve memory usage and performance with Swift* — WWDC25 312 | WWDC25 308, WWDC25 226 |
| App-wide direction for the cycle | *Platforms State of the Union* — WWDC26 102 | prior years' 102 |

Note the ID collision across years: WWDC25 268 is *Embracing Swift concurrency*; WWDC26 268 is
*Profile, fix, and verify*. Always carry the year with the ID.

## WWDC26 (current cycle — Swift 6.3/6.4, Xcode 27)

**Swift and tooling**
- 262 — What's new in Swift
- 258 — What's new in Xcode 27
- 259 — Xcode, agents, and you
- 267 — Migrate to Swift Testing
- 261 — Build, deliver, and automate with Xcode Cloud
- 260 — Get the most out of Device Hub
- 265 — Build real-time apps and services with gRPC and Swift

**SwiftUI**
- 269 — What's new in SwiftUI
- 321 — Dive into lazy stacks and scrolling with SwiftUI
- 322 — Compose advanced graphics effects with SwiftUI
- 272 — Use SwiftUI with AppKit and UIKit
- 271 — Code-along: Build powerful drag and drop in SwiftUI
- 278 — Modernize your UIKit app
- 289 — Modernize your AppKit app

**SwiftData and persistence**
- 274 — What's new in SwiftData
- 275 — Code-along: Add persistence with SwiftData

**Performance and diagnostics**
- 268 — Profile, fix, and verify: Improve app responsiveness with Instruments
- 222 — Meet the new MetricKit

**App surfaces and system integration**
- 277 — WidgetKit foundations
- 223 — Live Activities essentials
- 370 — Elevate your app's text experience with TextKit
- 345 — Discover new capabilities in the App Intents framework
- 343 — Explore advanced App Intents features for Siri and Apple Intelligence
- 240 — Build intelligent Siri experiences with App Schemas
- 295 — Validate your App Intents adoption with AppIntentsTesting

**Security**
- 201 — Secure your apps with App Attest
- 347 — Secure your app: mitigate risks to agentic features

**On-device AI (Swift-facing)**
- 241 — What's new in the Foundation Models framework
- 324 — Meet Core AI
- 326 — Integrate on-device AI models into your app using Core AI
- 242 — Build agentic app experiences with the Foundation Models framework
- 299 — Create robust evaluations for agentic apps

**Group labs** (long-form Q&A; useful for edge-case rationale, weaker as a citation)
- 8001 Swift · 8006 SwiftUI · 8017 SwiftData · 8003 Power and Performance · 8013 Xcode Tips

**Keynote-level**
- 102 — Platforms State of the Union

## WWDC25 (Swift 6.2, Xcode 26, iOS 26)

- 245 — What's new in Swift
- 268 — Embracing Swift concurrency *(the primary source on approachable concurrency and default `@MainActor` isolation)*
- 270 — Code-along: Elevate an app with Swift concurrency
- 266 — Explore concurrency in SwiftUI
- 256 — What's new in SwiftUI
- 323 — Build a SwiftUI app with the new design
- 273 — Meet SwiftUI spatial layout
- 280 — Code-along: Cook up a rich text experience in SwiftUI with AttributedString
- 282 — Make your UIKit app more flexible
- 291 — SwiftData: Dive into inheritance and schema migration
- 247 — What's new in Xcode 26
- 344 — Record, replay, and review: UI automation with Xcode
- 308 — Optimize CPU performance with Instruments
- 306 — Optimize SwiftUI performance with Instruments
- 312 — Improve memory usage and performance with Swift
- 226 — Profile and optimize power usage in your app
- 311 — Safely mix C, C++, and Swift
- 307 — Explore Swift and Java interoperability
- 286 — Meet the Foundation Models framework

## Earlier cycles — still-current foundations

Verified sessions whose concepts haven't been superseded. Always confirm against the newest
cycle before quoting one as current guidance.

**WWDC24 (Swift 6, Xcode 16)**
- 10136 — What's new in Swift
- 10169 — Migrate your app to Swift 6
- 10179 — Meet Swift Testing
- 10135 — What's new in Xcode 16
- 10144 — What's new in SwiftUI

**WWDC23 (Observation, SwiftData debut)**
- 10149 — Discover Observation in SwiftUI
- 10187 — Meet SwiftData
- 10196 — Dive deeper into SwiftData
- 10160 — Demystify SwiftUI performance
- 10148 — What's new in SwiftUI

## Refreshing this index

It goes stale every June, which costs a search and never costs correctness. To refresh:

1. Browse `https://developer.apple.com/videos/wwdc<year>/` — the full catalog with titles and IDs.
2. Cross-check the per-topic guides at `https://developer.apple.com/wwdc<yy>/guides/<topic>/`
   (e.g. `swift`, `swiftui`, `ios`) for Apple's own framing of the cycle.
3. Move superseded entries down into "Earlier cycles" rather than deleting them — an older
   session is still the right citation for when a behavior was introduced.
4. Update the "as of" date and current-cycle line at the top.

Only add an entry whose title and ID you have actually seen on an Apple page. A plausible-looking
invented session ID is the single worst failure this index can have.
