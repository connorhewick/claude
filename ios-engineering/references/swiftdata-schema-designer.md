# SwiftData Schema Designer

Design persistence schemas for production iOS apps — SwiftData first, with Core Data as the
deliberate fallback for the needs SwiftData still doesn't cover.

---

## Overview

By 2026, SwiftData is the default starting point for new persistence work: `@Model` macros, no
`.xcdatamodeld` editor, automatic lightweight migration via `VersionedSchema`/
`SchemaMigrationPlan`, and native Swift concurrency instead of a queue-and-context dance. Recent
releases closed most of the early gaps — sectioned `@Query`, `@Attribute(.codable)` for types
you don't own, `ResultsObserver`/`HistoryObserver` for non-SwiftUI observation. Core Data remains
the right tool for a specific, narrower set of needs: very large object graphs, heavyweight
migrations that transform data rather than just add fields, or an existing store already built on
it. The guiding rule is unchanged from Core Data's own era: model for how the app *reads* (fetches
drive design), keep every schema version migratable, and treat writes and reads as separate
concurrency domains — only *how* you express that changed.

## Core Concepts

**`@Model` is the schema — own the type, not a generated file.** A `@Model` class *is* the
persisted entity: stored properties become columns, no separate schema editor to keep in sync,
no codegen step to forget to run. Add computed properties, conformances, and domain logic
directly on the type, the same freedom Core Data's Category/Extension codegen used to require a
workaround for.

**Relationships keep the same ownership vocabulary, expressed as `@Relationship`.** The delete-rule
vocabulary carries over exactly: **`.cascade`** = "I own you" (deleting the parent deletes the
children); **`.nullify`** = "we're acquainted" (deleting one side clears the reference, the other
survives); **`.deny`** = block deletion while dependents exist. Every relationship should still
declare its rule deliberately — SwiftData infers an inverse automatically from a `@Relationship`
pair, but the delete rule is never inferred correctly enough to leave at the default for anything
but the most obviously-owned child.

**Fetching: `@Query` in SwiftUI, `ResultsObserver`/`HistoryObserver` everywhere else.** `@Query`
stays the default for SwiftUI lists — predicate + sort, live-updating, no notification plumbing,
and as of 2026 `#Predicate` compares enum values directly and composes via `Predicate(all:)`/
`Predicate(any:)` instead of hand-rolled boolean chains. `sectionBy:` moves grouping into the
query itself instead of a manual `Dictionary(grouping:)` pass after the fetch — the wrapped value
stays a plain array for source compatibility, so iterate the projected value's `.sections` (e.g.
`_orders.sections`) to get grouped `Section`s, and only a stored (not computed) property can be a
grouping key. Outside SwiftUI (a view model, a background pipeline), `ResultsObserver` gives
`@Query`-equivalent fetching and observation without a View in the call stack — it's `Observable`,
not callback-based, so read its `results` property instead of hand-rolling `NotificationCenter`
observation of context saves. For the different job of reacting to the raw stream of persisted
changes (a sync engine watching for new writes), reach for `HistoryObserver` instead — it exposes
an observable `eventCounter` you pair with `ModelContext.fetchHistory`, filterable by model type
and transaction author so you don't re-process your own writes.

**`ModelContext` is not `Sendable` — the concurrency rule is the same shape as Core Data's, just
lighter syntax.** A `ModelContext` (and the models it produced) belongs to one isolation domain.
The main `ModelContext` (from `.modelContainer(for:)`'s environment) drives UI reads; writes that
matter for responsiveness go through a `ModelActor`, which owns its own context and is safe to
call from a background task. Pass `PersistentIdentifier`s across that boundary, not model
instances — the direct analogue of Core Data's "pass `objectID`s, never objects" rule.

**`@Attribute(.codable)` is an escape hatch, not a default.** For a type you don't own (a
third-party value type, something with irregular shape) that can't cleanly become a set of
`@Model` stored properties, `.codable` persists it as an encoded blob. The cost: no predicate
filtering, no sorting, no fine-grained migration awareness on its internals — reach for it only
when decomposing the type into real attributes isn't practical, not as a shortcut past modeling.

**Migration is `VersionedSchema` + `SchemaMigrationPlan`, and the discipline hasn't gotten any
lighter.** Additive changes (new attribute, new optional relationship) migrate automatically
between schema versions in a plan. Anything that transforms data — splitting a field, changing a
type's meaning, merging entities — needs an explicit `MigrationStage.custom` with `willMigrate`/
`didMigrate` closures. The Core Data-era rule still applies without modification: never edit a
shipped schema version, and test migration from every version you've actually shipped, asserting
on the resulting data — not just that the migration didn't throw.

**Know when to reach for Core Data instead.** SwiftData covers the large majority of new schema
work, but four things still push toward Core Data: a **very large or deeply nested object graph**
(SwiftData's model loading is less fine-grained about faulting than Core Data's, and large graphs
can load more eagerly than you want); a **heavyweight/mapping-model migration** (SwiftData's
migration story is lightweight-first; complex multi-entity transformations are still more
explicit and better-tooled in Core Data); a need for **CloudKit shared or public database sync**
(SwiftData's CloudKit integration remains private-database-only as of mid-2026; multi-user shared
records still require `NSPersistentCloudKitContainer`); or an **existing Core Data store** with
real production data and a working migration history — don't rewrite a stable store to chase a
newer framework without a concrete reason tied to a feature you actually need.

## Decision Framework

| Decision | Choose | When |
|---|---|---|
| SwiftData vs Core Data | **SwiftData** | Default for new schema work — greenfield or a well-isolated new feature area, targeting the platform's SwiftData floor |
| | **Core Data** | Very large/deeply nested object graphs, heavyweight data-transforming migrations, CloudKit shared/public database sync, or an existing store already on it with no concrete reason to migrate |
| Delete rule | `.cascade` | Parent exclusively owns children (Order→Items) |
| | `.nullify` | Reference to a shared/independent entity (Item→Product) |
| | `.deny` | Deletion must be blocked while dependents exist (audit invariant) |
| Fetching in SwiftUI | `@Query` (with `sectionBy:` if grouped) | Any SwiftUI list/detail driven by persisted data |
| Fetching outside SwiftUI | `ResultsObserver` | View model or background code needs live, observed results without a View |
| Reacting to background writes | `HistoryObserver` | Non-SwiftUI code needs a signal when persistent history changes (e.g. a sync engine) |
| A type you don't own, awkward to model | `@Attribute(.codable)` | Only after decomposing into real attributes is impractical — costs queryability and migration granularity |
| Context for a write that matters for responsiveness | `ModelActor`-owned background context | Anything beyond a trivial, immediate main-context write |
| Migration | Automatic (in a `SchemaMigrationPlan` stage) | Additive/renaming changes |
| | `MigrationStage.custom` | Data transformation, entity merges, multi-version jumps |
| | Consider Core Data instead | Migration needs fine-grained, multi-pass data transformation SwiftData can't express cleanly |

## Workflow

1. **Read the existing code.** If the project already has a Core Data stack with real shipped
   data, that's a strong signal to extend it rather than introduce a second persistence engine for
   one feature — apply the Core Data patterns below instead. For new schema work, check the
   platform floor supports SwiftData before assuming it does.
2. **Inventory the read paths.** List every screen/query that will fetch this data, with filters,
   sort orders, and whether results need sectioning. The schema serves these fetches.
3. **Define `@Model` types**: stored properties typed as real Swift types where possible; reach for
   `@Attribute(.codable)` only for types that resist decomposition.
4. **Define relationships**: `@Relationship` with an explicit delete rule per the ownership
   vocabulary above; avoid ordered to-many relationships where a sort attribute will do.
5. **Design the concurrency story**: main context for reads/UI, a `ModelActor` for background
   writes, `PersistentIdentifier`s crossing the boundary — written down, not implied.
6. **Plan the migration**: if the schema changed from a shipped version, add a new
   `VersionedSchema`, decide automatic vs. `.custom` per change, and write the migration test from
   each shipped version's seeded store.
7. **Wire fetches**: `@Query`/`ResultsObserver` with predicates and `sectionBy:` matching step 2's
   inventory; avoid loading large graphs eagerly where a narrower fetch would do.
8. **Verify against the Quality Checklist**, including a migration test from every shipped schema
   version.

## Patterns

### `@Model` entity with relationships and delete rules

```swift
@Model
final class Order {
    var remoteID: String
    var createdAt: Date
    var status: OrderStatus

    @Relationship(deleteRule: .cascade, inverse: \LineItem.order)
    var lineItems: [LineItem] = []

    init(remoteID: String, createdAt: Date, status: OrderStatus) {
        self.remoteID = remoteID
        self.createdAt = createdAt
        self.status = status
    }

    var isOverdue: Bool { status == .open && createdAt < .now.addingTimeInterval(-86_400 * 14) }
}

@Model
final class LineItem {
    var quantity: Int
    var order: Order?

    @Relationship(deleteRule: .nullify)     // reference to a shared, independently-owned entity
    var product: Product?

    init(quantity: Int, product: Product?) {
        self.quantity = quantity
        self.product = product
    }
}
```

### Container setup, main reads, `ModelActor` writes

```swift
let container = try ModelContainer(for: Order.self, LineItem.self, Product.self)

// App root:
// WindowGroup { RootView() }.modelContainer(container)
// Views read/write the main context via @Environment(\.modelContext) for trivial, immediate writes.

@ModelActor
actor OrderImporter {
    func importOrders(_ dtos: [OrderDTO]) throws -> [PersistentIdentifier] {
        var ids: [PersistentIdentifier] = []
        for dto in dtos {
            let order = Order(remoteID: dto.id, createdAt: dto.createdAt, status: dto.status)
            modelContext.insert(order)
            ids.append(order.persistentModelID)
        }
        try modelContext.save()          // merges into observers of the main context automatically
        return ids                        // IDs cross the boundary; model instances never do
    }
}
```

### Sectioned, live `@Query` in SwiftUI

```swift
struct OpenOrdersView: View {
    @Query(filter: #Predicate<Order> { $0.status == .open },
           sort: \.createdAt,
           order: .reverse,
           sectionBy: \.status)                 // grouping moves into the query itself
    private var orders: [Order]                 // wrapped value stays a plain, flat array

    var body: some View {
        List {
            ForEach(_orders.sections) { section in     // projected value exposes the grouping
                Section(section.id.rawValue) {
                    ForEach(section) { order in OrderRow(order: order) }
                }
            }
        }
    }
}
```

### `ResultsObserver`-style observation for non-SwiftUI code

SwiftData's WWDC-2026 non-SwiftUI observer type gives `@Query`-equivalent fetching and
observation without a View in the call stack — it's `Observable`, not callback-based, so you read
its results property instead of hand-rolling `NotificationCenter` observation of context saves.
**Its exact type name and initializer signature are still unsettled across current sources as of
this writing** (early docs and WWDC session material disagree between `ResultsObserver`,
`ModelResultsObserver`, and `ResultObserver`) — confirm the precise symbol against your SDK's
current SwiftData headers before writing this code, rather than trusting any specific signature
here.

```swift
@Observable
final class OrderBadgeCounter {
    // Exact type/initializer: verify against your SDK — see note above.
    private let observer: /* SwiftData's Observable results-observer type */

    init(modelContext: ModelContext) throws {
        observer = try /* ...Observer */(modelContext: modelContext, /* fetch config */: .init(
            predicate: #Predicate<Order> { $0.status == .open }
        ))
    }

    // Observable — stays current with no callback or NotificationCenter plumbing to write
    var count: Int { observer.results.count }
}
```

### `@Attribute(.codable)` for a type you don't own

```swift
@Model
final class Order {
    // ThirdPartyShippingLabel doesn't decompose cleanly into stored properties.
    @Attribute(.codable) var shippingLabel: ThirdPartyShippingLabel?
    // Cost accepted deliberately: no predicate filtering or sort on shippingLabel's internals.
}
```

### Migration with `VersionedSchema` + `SchemaMigrationPlan`

```swift
enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Order.self, LineItem.self, Product.self] }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.custom(
            fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                // e.g. backfill a new non-optional field from an old one, then save.
                try? context.save()
            }
        )]
    }
}

func testMigration(fromSeededV1Store url: URL) throws {
    let container = try ModelContainer(
        for: Schema(versionedSchema: AppSchemaV2.self),
        migrationPlan: AppMigrationPlan.self,
        configurations: .init(url: copyToTemp(url))
    )
    let count = try container.mainContext.fetchCount(FetchDescriptor<Order>())
    XCTAssertEqual(count, expectedSeedCount)   // data survived, not just "container loaded"
}
```

### Falling back to Core Data (large graphs, heavyweight migration, CloudKit sharing, existing store)

The concurrency and delete-rule rules are identical in spirit — only the API surface differs:
every `NSManagedObject` access happens inside its context's `perform`/`await context.perform {}`;
writes go through `container.newBackgroundContext()`, never `viewContext`; `objectID`s cross
threads, never objects; every relationship gets an explicit delete rule and an inverse; migrations
are tested from every shipped model version with a seeded real store, using a mapping model for
anything beyond additive/renaming changes. Reach for this path only when one of the four
Decision Framework triggers above actually applies — not as a default.

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Data silently doesn't persist | Relying on autosave timing instead of an explicit `try context.save()` after a meaningful write | Save explicitly after writes that matter; treat autosave as a safety net, not the save path |
| Bidirectional relationship shows stale/inconsistent state after init | Both sides of a relationship set independently instead of through the inverse | Set one side and let SwiftData maintain the inverse; verify with a round-trip fetch in a test |
| Memory balloons / UI stalls on a big list | Large or deeply nested object graph loaded eagerly | Narrow the `FetchDescriptor` (predicate, `fetchLimit`), or move this entity to Core Data if the graph is fundamentally large |
| Migration works for the schema I just wrote, fails for users three versions back | Only tested migration from the immediately prior version | Seed a real store per shipped `VersionedSchema` and test migration from each one, asserting data |
| Sectioned `@Query` doesn't compile, or grouped list never updates | Declared the property as a `SectionedResults` type instead of a plain array, or grouped on a computed/transient property | Keep the wrapped value `[Model]`; read the projected value's `.sections`; group only on a stored property |
| Multi-user shared records silently only sync to the owner's private database | Assumed SwiftData's CloudKit integration covers shared/public databases | Use `NSPersistentCloudKitContainer` (Core Data) for CloudKit-shared records; SwiftData is private-database-only |
| `@Attribute(.codable)` field can't be filtered or sorted, feature silently degrades | Reaching for `.codable` as a shortcut instead of decomposing the type | Model real attributes; reserve `.codable` for types that genuinely resist decomposition |
| Random crashes touching a fetched model from a background queue | `ModelContext`/its models used outside their owning isolation domain | Own writes with a `ModelActor`; pass `PersistentIdentifier`, never the model instance, across the boundary |
| Rebuilding the whole persistence layer for a feature that needed one Core Data capability | Migrating a stable, working Core Data store to SwiftData without a concrete blocking need | Keep the existing store; add the new feature's schema in whichever engine already owns that data |
| Complex multi-entity migration silently produces wrong data | Forced an inherently heavyweight, transforming migration through SwiftData's lightweight-first model | Use `MigrationStage.custom` for anything beyond additive changes, or fall back to a Core Data mapping model if the transformation is large enough |

## Quality Checklist

- [ ] SwiftData is the default; Core Data is used only where a large/nested graph, a heavyweight
      transforming migration, CloudKit shared/public sync, or an existing store justifies it
- [ ] Every relationship has an explicit, justified delete rule (`.cascade` = ownership,
      `.nullify` = reference, `.deny` sparingly)
- [ ] Writes that matter for responsiveness go through a `ModelActor`; `PersistentIdentifier`s —
      never model instances — cross isolation boundaries
- [ ] `@Query`/`ResultsObserver` predicates and `sectionBy:` match the actual read paths
      inventoried up front, not fetched-then-filtered in Swift
- [ ] `@Attribute(.codable)` used only where decomposition into real attributes is impractical,
      with the query/sort/migration cost accepted deliberately
- [ ] Migration tested from **every shipped schema version** using seeded real stores, asserting
      data survived — not just that the container loaded
- [ ] No shipped `VersionedSchema` ever edited in place; transforming changes use
      `MigrationStage.custom`
- [ ] Explicit `try context.save()` after writes that matter — not relied on autosave timing
- [ ] If Core Data is used instead: managed-object access confined to `perform`/
      `performAndWait`, writes on background contexts, explicit merge policy, every relationship's
      inverse and delete rule set, migration tested from every shipped model version
