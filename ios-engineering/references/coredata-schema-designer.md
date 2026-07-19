# Core Data Schema Designer

Design Core Data entity schemas, relationships, delete rules, concurrency, and migrations for production iOS apps — with an eye on SwiftData's future.

---

## Overview

Core Data is an object graph manager with persistence, not a SQL database — and almost every production incident traces back to forgetting that: threading violations, fault storms, and migrations designed as afterthoughts. This skill designs schemas where the graph shape, delete rules, and concurrency story are decided *up front*, because they are the things you cannot cheaply change once user data exists in the wild. The guiding rule: model for how the app *reads* (fetches drive design), keep every model version migratable, and treat the main context as a read-only view of work done in the background.

## Core Concepts

**Relationships are graph edges with ownership semantics — delete rules encode the ownership.** Every relationship needs an inverse (Core Data maintains consistency through it; a missing inverse is a warning today and a data-integrity bug tomorrow) and a deliberate delete rule. The vocabulary: **Cascade** = "I own you" (Order → LineItems: deleting the order deletes its items); **Nullify** = "we're acquainted" (LineItem → Product: deleting an item must not delete the catalog product); **Deny** = "you can't delete me while children exist" (rare, for hard invariants); **No Action** = a dangling-reference generator — treat it as a bug unless you can write a paragraph defending it. Wrong delete rules either orphan rows forever (Nullify where Cascade was meant) or silently destroy shared data (Cascade pointing at a shared entity).

**Codegen: Category/Extension is the production default.** *Class Definition* generates the whole class invisibly — fine for toy apps, but you can't add conveniences, conformances, or domain logic to the type without extensions in awkward places. *Category/Extension* generates the properties but lets you own the class declaration: add computed properties, `Identifiable`, validation. *Manual/None* is for when you need custom accessors or to keep generated code in the repo for review. Never hand-edit generated files; never mix strategies within one model without a reason.

**Fetches are where performance lives.** Core Data returns *faults* (lazy placeholders) by default; the catastrophic pattern is fetching 10,000 faults and touching one property on each — 10,000 individual SQL round-trips ("fault storm"). Counter-tools, in order: `fetchBatchSize` (rows materialize in batches as the UI scrolls — the default for any list); `relationshipKeyPathsForPrefetching` (kills N+1 on relationships you'll display); predicate + `fetchLimit` (filter in SQLite, never in Swift — `results.filter {}` after an unbounded fetch is the #1 memory bug); `propertiesToFetch` + dictionary result type for aggregates; indexes on attributes used in predicates/sort descriptors (and a uniqueness constraint on any external ID you upsert by).

**Concurrency: one rule, zero exceptions.** An `NSManagedObject` and its context belong to one queue; touch them only inside that context's `perform`/`performAndWait` (or `await context.perform {}`). Pass `NSManagedObjectID`s between contexts, never objects. Architecture: `NSPersistentContainer`'s `viewContext` for reading/driving UI; `newBackgroundContext()` (or `performBackgroundTask`) for all writes; `viewContext.automaticallyMergesChangesFromParent = true` so saves flow to the UI; an explicit `mergePolicy` (usually `NSMergeByPropertyObjectTrumpMergePolicy` for "latest local write wins") because the default policy *throws* on conflict and most apps discover that in production. Enable `-com.apple.CoreData.ConcurrencyDebug 1` in every Debug scheme — it turns latent threading bugs into immediate crashes where you can fix them.

**Migrations are a contract with every version you ever shipped.** Lightweight migration handles: adding/removing entities and attributes, renaming via *renaming identifiers* (set the ID — don't rely on inference), optionality changes, simple relationship changes. It cannot transform data (splitting `fullName` into two fields, changing types with semantics, merging entities) — that needs a mapping model/heavyweight migration, which loads both stacks and is slow and memory-hungry on big stores; for multi-version jumps, *staged* migrations (vN → vN+1 → …, or iOS 17's `NSStagedMigrationManager`) keep each step lightweight. Operational rules: never edit a shipped model version — always *Editor → Add Model Version*; keep every historical `.xcdatamodel` in the bundle forever; test migration from **every shipped version** with a real seeded store, because the user upgrading from three versions ago is the one who crash-loops.

**SwiftData is the same engine with a Swift-native face.** `@Model` macros, no `.xcdatamodeld`, automatic lightweight migration via `VersionedSchema`/`SchemaMigrationPlan`. Choose it for new apps targeting iOS 17+ with straightforward needs. Stay on Core Data when you need: `NSFetchedResultsController`-grade granular change tracking, abstract entities, advanced fetch features (batch updates/deletes with more control), derived attributes, pre-17 support, or proven CloudKit mirroring behavior. To keep a Core Data schema SwiftData-migratable later: same store URL, entity names matching future class names, attributes expressible as Swift types (avoid exotic `Transformable` payloads — use `Codable` data blobs), and uniqueness constraints SwiftData's `@Attribute(.unique)` can mirror.

## Decision Framework

| Decision | Choose | When |
|---|---|---|
| Core Data vs SwiftData | SwiftData | New app, iOS 17+, no need for FRC-grade change tracking or abstract entities |
| | Core Data | Pre-17 support, complex fetches, mature CloudKit sync, existing store |
| Delete rule | Cascade | Parent exclusively owns children (Order→Items) |
| | Nullify | Reference to shared/independent entity (Item→Product) |
| | Deny | Deletion must be blocked while dependents exist (audit invariant) |
| Codegen | Category/Extension | Default — own the class, generated properties |
| | Manual/None | Custom accessors, or generated code must be reviewable in-repo |
| Big binary data | External file + path/`allowsExternalBinaryDataStorage` | Anything that can exceed ~100 KB; never image blobs inline |
| Context for a write | `newBackgroundContext().perform {}` | Always — `viewContext` writes block the UI and invite deadlocks |
| Migration | Lightweight | Additive/renaming changes (with renaming identifiers) |
| | Mapping model / staged | Data transformation, entity merges, multi-version jumps |
| List UI data source | `NSFetchedResultsController` (or `@FetchRequest`) | Driving table/collection/SwiftUI lists with live updates |
| Upsert from API | Uniqueness constraint + `NSMergeByPropertyObjectTrump` | Syncing external records by stable ID |

## Workflow

1. **Read the existing code.** Open the `.xcdatamodeld` (all versions), the persistence stack setup, merge policies, any `NSPersistentCloudKitContainer` use, and the migration history. List shipped model versions — they define what you must remain compatible with.
2. **Inventory the read paths.** List every screen/query that will fetch this data, with filters and sort orders. The schema serves these fetches; design indexes and relationships from them, not from an ERD aesthetic.
3. **Define entities and attributes**: scalar types where possible, optionality chosen deliberately (Core Data optional ≠ Swift optional — make them agree), uniqueness constraints on external IDs, large blobs externalized.
4. **Define relationships**: every one has an inverse; assign delete rules using the ownership vocabulary; prefer to-many with ordering handled by a sort attribute (ordered relationships have poor performance and CloudKit incompatibilities).
5. **Choose codegen** (default Category/Extension) and add domain extensions.
6. **Design the concurrency story**: container setup, background-write/main-read split, merge policy, automatic merging — written down, not implied.
7. **Plan the migration**: if the model changed, add a new version, set renaming identifiers, decide lightweight vs staged/mapping, and write the migration test from each shipped version's seeded store.
8. **Wire fetches** with `fetchBatchSize`, prefetching, and indexes matching step 2's inventory.
9. **Verify against the Quality Checklist**, with `-com.apple.CoreData.ConcurrencyDebug 1` enabled during the test run.

## Patterns

### Stack setup with explicit policies

```swift
final class PersistenceController {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AppModel")
        if inMemory {  // unit tests: real model, throwaway store
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first!
            .setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        container.loadPersistentStores { _, error in
            if let error { fatalError("Store failed to load: \(error)") } // surface, don't limp
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
```

### Background write, main read, IDs across the seam

```swift
func importOrders(_ dtos: [OrderDTO]) async throws -> [NSManagedObjectID] {
    let context = container.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy  // upsert via unique "remoteID"
    return try await context.perform {
        let orders = dtos.map { dto -> Order in
            let order = Order(context: context)
            order.remoteID = dto.id        // uniqueness constraint turns insert into upsert
            order.total = dto.total
            return order
        }
        try context.save()                 // merges into viewContext automatically
        return orders.map(\.objectID)      // IDs cross threads; objects never do
    }
}
// On the main side: let order = viewContext.object(with: id) as! Order
```

### Fetch tuned for a list (no fault storm, no N+1)

```swift
let request = Order.fetchRequest()
request.predicate = NSPredicate(format: "status == %@ AND createdAt >= %@",
                                OrderStatus.open.rawValue, cutoff as NSDate)
request.sortDescriptors = [NSSortDescriptor(keyPath: \Order.createdAt, ascending: false)]
request.fetchBatchSize = 40                                  // materialize as the UI scrolls
request.relationshipKeyPathsForPrefetching = ["lineItems"]   // kill the N+1 on display
// "status" and "createdAt" carry fetch indexes in the model editor — predicate runs in SQLite.
```

### Owning the class with Category/Extension codegen

```swift
// Codegen: Category/Extension generates the @NSManaged properties elsewhere.
@objc(Order)
final class Order: NSManagedObject, Identifiable {}

extension Order {
    var isOverdue: Bool { dueDate.map { $0 < .now } ?? false }   // domain logic lives with the type

    static func openOrders() -> NSFetchRequest<Order> {           // canonical fetches as factories
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", OrderStatus.open.rawValue)
        return request
    }
}
```

### Live list: @FetchRequest (SwiftUI) over manual fetching

```swift
struct OpenOrdersView: View {
    @FetchRequest(fetchRequest: Order.openOrders(),    // reuse the canonical factory
                  animation: .default)
    private var orders: FetchedResults<Order>

    var body: some View {
        List(orders) { order in OrderRow(order: order) }
        // Updates automatically when background saves merge into viewContext —
        // no notification plumbing, no manual refresh. UIKit equivalent:
        // NSFetchedResultsController + diffable data source snapshot in the delegate.
    }
}
```

### Batch delete that keeps contexts honest

```swift
// NSBatchDeleteRequest runs in SQLite and BYPASSES the contexts — without the merge step,
// viewContext keeps showing deleted objects until relaunch.
try await container.performBackgroundTask { context in
    let fetch: NSFetchRequest<NSFetchRequestResult> = Order.fetchRequest()
    fetch.predicate = NSPredicate(format: "status == %@ AND createdAt < %@",
                                  OrderStatus.archived.rawValue, cutoff as NSDate)
    let request = NSBatchDeleteRequest(fetchRequest: fetch)
    request.resultType = .resultTypeObjectIDs
    let result = try context.execute(request) as! NSBatchDeleteResult
    NSManagedObjectContext.mergeChanges(
        fromRemoteContextSave: [NSDeletedObjectsKey: result.result as! [NSManagedObjectID]],
        into: [container.viewContext])     // tell the in-memory graph what SQLite already did
}
// Caveat: batch deletes do NOT honor delete rules — cascade children manually or include
// them in the predicate. Only safe down ownership edges you handle explicitly.
```

### Lightweight migration with renaming identifiers, tested per shipped version

```swift
// Model v3: "createdDate" renamed to "createdAt" — set Renaming ID "createdDate" on the
// new attribute in the model editor; inference alone treats rename as delete+add (data loss).

func testMigration(fromVersion version: String) throws {
    let sourceURL = bundleStore(seededFor: version)        // real .sqlite captured per release
    let model = NSManagedObjectModel.mergedModel(from: nil)!
    let container = NSPersistentContainer(name: "AppModel", managedObjectModel: model)
    container.persistentStoreDescriptions = [.init(url: copyToTemp(sourceURL))]
    container.loadPersistentStores { _, error in XCTAssertNil(error) }   // migration happens here
    let count = try container.viewContext.count(for: Order.fetchRequest())
    XCTAssertEqual(count, expectedSeedCount(for: version)) // data survived, not just "no crash"
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Random `EXC_BAD_ACCESS` / corrupt values, worse under load | `NSManagedObject` used outside its context's queue | All access inside `perform {}`; pass `objectID` between contexts; ConcurrencyDebug=1 in Debug |
| Scrolling a list issues thousands of tiny SQL queries | Fault storm: unbatched fetch, properties touched per row | `fetchBatchSize`, prefetch displayed relationships, index predicate attributes |
| Memory balloons on large datasets | `fetchLimit`-less fetch then `filter {}` in Swift; blobs stored inline | Predicate in the fetch request; external storage for binaries; batch size |
| Save throws `NSMergeConflict` in production | Default error-merge policy with concurrent writers | Set an explicit merge policy on every writing context; funnel writes through one background path |
| Users upgrading from old versions crash on launch | Migration tested only from N-1, or a shipped model version was edited in place | Never edit shipped versions; keep all versions; automated migration tests from each shipped store |
| Rename silently wiped a column's data | Lightweight migration inferred rename as delete+add | Set the renaming identifier on the renamed attribute/entity |
| Deleting a record nukes shared reference data | Cascade rule pointing at a shared entity | Cascade only down ownership edges; Nullify toward shared entities; audit every rule |
| Orphan rows accumulate forever | Nullify where the parent actually owned the children | Cascade from owner to owned; add cleanup migration for existing orphans |
| UI doesn't reflect background saves | `automaticallyMergesChangesFromParent` left false | Enable it on `viewContext`; verify with an FRC-driven screen |
| Duplicated records after every sync | Insert-always import, no uniqueness | Uniqueness constraint on the external ID + `NSMergeByPropertyObjectTrump` upsert |
| "Multiple NSEntityDescriptions claim the NSManagedObject subclass" in tests | Model loaded twice (per test, per container) | Load the `NSManagedObjectModel` once, share across test containers |

## Quality Checklist

- [ ] Every managed object access occurs inside its context's `perform`/`performAndWait`; `objectID`s — never objects — cross contexts
- [ ] All writes on background contexts; `viewContext` reads only, with `automaticallyMergesChangesFromParent = true`
- [ ] Explicit merge policy on every writing context (conflict behavior chosen, not defaulted)
- [ ] Every relationship has an inverse and a justified delete rule (Cascade = ownership, Nullify = reference, No Action absent)
- [ ] Migration tested from **every shipped model version** using seeded real stores, asserting data — not just load success
- [ ] No shipped `.xcdatamodel` version ever edited; renames carry renaming identifiers
- [ ] Uniqueness constraints on externally-synced IDs; imports are upserts, not blind inserts
- [ ] List fetches use `fetchBatchSize` and prefetch displayed relationships; predicates/sorts backed by fetch indexes
- [ ] Filtering/limiting happens in the fetch request (SQLite), never post-fetch in Swift
- [ ] Large binaries externalized (external storage or file + path), never inline blobs
- [ ] Codegen strategy uniform (Category/Extension default); no hand-edited generated files
- [ ] `-com.apple.CoreData.ConcurrencyDebug 1` set in Debug schemes and the test plan
- [ ] SwiftData posture documented: either adopted (iOS 17+, needs fit) or schema kept migratable (Swift-expressible types, stable entity names, mirrorable unique constraints)
