# SwiftUI Patterns

Produce SwiftUI views (Swift 5.9+, iOS 17 era — `@Observable`, `NavigationStack`, `#Preview`)
that re-render minimally, manage state with clear ownership, and stay testable and previewable
as the app grows.

## Overview

SwiftUI is a function from state to view description. Almost every SwiftUI bug — stale UI,
lost text-field input, animation glitches, jank — is really a state-ownership or view-identity
bug wearing a costume. The core philosophy: **decide who owns each piece of state, keep view
identity stable, and keep `body` cheap.** Get those three right and SwiftUI's diffing does the
performance work for you; get them wrong and no amount of `drawingGroup()` will save you.

## Core Concepts

### State has exactly one owner

Every piece of state needs one owner; everyone else borrows. `@State` owns (SwiftUI keeps it
alive across view-struct recreation — the struct is a cheap description, the `@State` storage
is the persistent thing). `@Binding` borrows read-write access from an owner. `@Environment`
injects shared dependencies down the tree without parameter drilling. The classic failure is
two sources of truth — a view model property *and* a local `@State` mirroring it — which then
drift and produce "stale UI" bugs that look like framework glitches.

### @Observable tracks property reads, not object references

With the `@Observable` macro (iOS 17+), a view re-evaluates only when a property *it actually
read in `body`* changes. This is the single biggest performance improvement over
`ObservableObject`, where any `@Published` change invalidated every observing view. Consequence:
with `@Observable`, fine-grained models are nearly free; with legacy `ObservableObject`, you
had to split objects to limit blast radius. Prefer `@Observable` for all new code; keep
`@StateObject`/`@ObservedObject` only where the deployment target forces it. Ownership still
matters: hold an owned `@Observable` model in `@State`, pass it down as a plain `let`, and use
`@Bindable` when a child needs bindings into it.

### Identity decides whether views update or get rebuilt

SwiftUI tracks views by identity: structural (position in the type tree) or explicit (`.id()`,
`ForEach` ids). Same identity → state preserved, changes animated. New identity → state
destroyed, view rebuilt from scratch. This is why `if/else` branches animate as remove/insert
(two identities) while a modifier with a ternary animates in place (one identity), and why
`ForEach(items.indices)` corrupts state when the array reorders — index 2 is *the same
identity* even when it's now a different element.

### body must be a pure, cheap description

`body` can run on every ancestor invalidation, every frame of an animation. Anything expensive
in it — date formatting, filtering, sorting, image decoding — multiplies across re-evaluations.
Compute upstream (in the model, or cached), and `body` just lays out results. Side effects
belong in `.task`/`.onChange`, never in `body` itself.

### MVVM in SwiftUI is lighter than UIKit MVVM

The view layer already binds; you don't need a view model per view. Use a `@MainActor
@Observable` model where there is real logic to test (loading, validation, multi-step flows).
For purely presentational views, `@State` + `let` parameters *is* the architecture. A
`FormatterViewModel` wrapping one computed string is ceremony, not architecture.

### Composition is the optimization

Small subviews aren't just style: each is its own invalidation unit, so extracting a subview
narrows what re-renders when its inputs change. Extract when `body` exceeds roughly a screen,
when a region has independent state, or when you need a reuse boundary. Pass values, not whole
models, where practical — narrower dependencies mean fewer re-evaluations.

## Decision Framework

| Need | Use |
|---|---|
| View-local, view-lifetime value state (toggle, text draft, sheet flag) | `@State` with private access |
| Child mutates parent-owned state | `@Binding` (create with `$`) |
| Reference-type model with logic, owned by this view | `@State` holding an `@Observable` class |
| Same model passed to a child | Plain `let`; `@Bindable` if the child needs `$model.field` bindings |
| App-wide dependency (router, session, theme) | `@Observable` model in `@Environment`, injected at the root |
| Deployment target < iOS 17 | `@StateObject` (own) / `@ObservedObject` (borrow) / `@EnvironmentObject` |
| Drill-down navigation, deep links, programmatic pop | `NavigationStack` with a typed `path` + `.navigationDestination` |
| Modal, self-contained flow | `.sheet`/`.fullScreenCover` driven by `Optional` item state |
| Large scrolling list of data | `List` (recycling, swipe actions) — default choice |
| Heterogeneous lazy scroll content, custom styling | `LazyVStack` in `ScrollView` |
| View model or plain view? | Logic worth unit testing → `@Observable` model; presentation only → `@State` + parameters |

## Workflow

1. **Read the existing code.** Identify the deployment target (decides `@Observable` vs
   `ObservableObject`), navigation style, existing design-system components, and how siblings
   structure state — match conventions before inventing.
2. **Sketch the state graph before writing views**: list every piece of state, its owner, and
   who reads/writes it. Resolve duplicate ownership now, on paper.
3. **Choose wrappers from the Decision Framework** — ownership first, wrapper second.
4. **Build the view tree top-down**, extracting subviews at state and invalidation boundaries;
   keep each `body` under a screenful.
5. **Wire navigation** with typed destinations; keep route values `Hashable` data, not views.
6. **Move all work out of `body`** — formatting and filtering into the model, effects into
   `.task`/`.onChange` (`.task` ties async work to view lifetime and auto-cancels).
7. **Add previews per meaningful state** (loading/error/long-text/dark mode) using `#Preview`
   with stub models — if a view can't be previewed without the network, its dependencies are
   wrong. This repo's `swiftui-rules` rule already requires a working `#Preview` on every
   SwiftUI view — this workflow satisfies that automatically.
8. **Verify**: run previews, check re-render behavior with `Self._printChanges()` on suspect
   views, test Dynamic Type and dark mode, then run the Quality Checklist.

## Patterns

### @Observable model owned via @State

```swift
@MainActor
@Observable
final class CheckoutModel {
    var items: [CartItem] = []
    var promoCode = ""
    private(set) var state: LoadState<Receipt> = .idle

    var total: Decimal { items.reduce(0) { $0 + $1.price } }  // computed here, not in body

    func submit(api: any CheckoutAPI) async {
        state = .loading
        do { state = .loaded(try await api.submit(items, promo: promoCode)) }
        catch { state = .failed(error) }
    }
}

struct CheckoutView: View {
    @State private var model = CheckoutModel()   // @State owns the @Observable

    var body: some View {
        Form {
            CartSection(items: model.items)              // reads only items
            PromoField(model: model)                     // needs a binding → @Bindable inside
            TotalRow(total: model.total)
        }
        .task { await model.loadCart() }
    }
}

struct PromoField: View {
    @Bindable var model: CheckoutModel
    var body: some View {
        TextField("Promo code", text: $model.promoCode)
    }
}
```

### Environment injection for app-wide dependencies

```swift
@Observable final class Session { var user: User? }

@main struct MyApp: App {
    @State private var session = Session()
    var body: some Scene {
        WindowGroup { RootView().environment(session) }
    }
}

struct AccountBadge: View {
    @Environment(Session.self) private var session
    var body: some View { Text(session.user?.displayName ?? "Guest") }
}
```

### NavigationStack with typed destinations

```swift
enum Route: Hashable {
    case product(Product.ID)
    case reviews(Product.ID)
}

struct CatalogView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ProductList(onSelect: { path.append(.product($0)) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .product(let id): ProductDetail(id: id)
                    case .reviews(let id): ReviewList(productID: id)
                    }
                }
        }
    }
}
```

Routes are `Hashable` data: deep links become `path = [.product(id), .reviews(id)]`, and
pop-to-root is `path.removeAll()`.

### Stable identity in lists

```swift
// Identifiable elements — never indices — so reorder/insert preserves row state.
List(messages) { message in          // Message: Identifiable
    MessageRow(message: message)
}
```

### Diagnosing re-renders

```swift
var body: some View {
    let _ = Self._printChanges()     // debug builds: logs WHY this body re-ran
    ...
}
```

### Previews as a state matrix

```swift
#Preview("Loaded") {
    CheckoutView(model: .stub(items: .sample))
}
#Preview("Error, dark, XXL type") {
    CheckoutView(model: .stub(state: .failed(URLError(.notConnectedToInternet))))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .xxxLarge)
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| UI sometimes stale, "needs a scroll to refresh" | Two sources of truth: `@State` copy of a model property, synced manually | One owner; child takes `@Binding`/`@Bindable` into the original |
| Text field loses input / row state jumps to another row | `ForEach(items.indices)` or unstable/reused `id`s | `Identifiable` elements with genuinely unique, stable ids |
| Whole screen re-renders on every keystroke | Pre-iOS-17 `ObservableObject` with everything `@Published`, observed at the top | Migrate to `@Observable` (per-property tracking) or split the object; verify with `Self._printChanges()` |
| Model resets every time parent re-renders (legacy) | `@ObservedObject` used where the view *owns* the object — recreated with the struct | `@StateObject` (or `@State` + `@Observable`) for owned models |
| Scroll jank on long lists | Eager `VStack` in `ScrollView` building every row; heavy per-row work in `body` | `List`/`LazyVStack`; precompute row data; downsample images off-main (see `swift-performance.md`) |
| Animations replace views instead of animating them | `if/else` creates two identities | Animate one identity via modifiers (`.opacity(...)`, ternaries) when in-place is intended |
| Crash: "No Observable object of type X found" | `@Environment(X.self)` without `.environment(x)` upstream (same with `@EnvironmentObject`) | Inject at the root; previews need injection too — make a `.stub` helper |
| `onAppear`-spawned work continues after dismiss; double-fires | Manual `Task {}` in `onAppear`, never cancelled | `.task { }` / `.task(id:)` — lifetime-bound and auto-cancelling |
| Mysterious full-tree rebuilds, broken animations | `AnyView` erasing structural identity, or giant 300-line `body` | Extract concrete subviews; reserve `AnyView` for genuinely heterogeneous storage |
| View impossible to preview | View reaches into singletons/network directly | Inject dependencies (init params or Environment); stub them in `#Preview` |

## Quality Checklist

- [ ] Every piece of state has exactly one owner; no `@State` mirrors of model properties
- [ ] Owned reference models: `@State` + `@Observable` (or `@StateObject` pre-iOS 17) — never `@ObservedObject` for owned objects
- [ ] All `ForEach`/`List` ids are stable and unique; no index-based identity over reorderable data
- [ ] `body` does no formatting, filtering, sorting, or I/O; computed values live in the model
- [ ] Async work uses `.task`/`.task(id:)`, not unmanaged `Task {}` in `onAppear`
- [ ] Models touching UI state are `@MainActor`
- [ ] Navigation uses `NavigationStack` with `Hashable` route values; deep-link and pop-to-root paths work
- [ ] No `AnyView` outside justified heterogeneous storage; subviews extracted at state boundaries
- [ ] `@State` is `private`; bindings are passed, not whole models, where a value suffices
- [ ] Every meaningful view state has a `#Preview` (loading, error, empty, long text)
- [ ] Dark mode and Dynamic Type (largest size) checked; semantic colors/fonts only
- [ ] Interactive elements have accessibility labels; decorative images marked decorative
- [ ] View-model logic (validation, loading transitions) covered by plain unit tests — no view rendering needed
