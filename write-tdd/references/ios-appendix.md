# Swift/iOS Implementation Notes

This appendix translates a finished TDD's API Contract, Data Model, and Service Design sections
into concrete Swift signatures for the **client-side** iOS app — **signatures only, no
implementations.** Method bodies end in `{ fatalError("TODO") }` or are simply omitted after the
signature; nothing here is working code. Mirror the TDD, don't extend it — if this appendix would
need content the TDD itself doesn't have, that's a gap in the TDD's own sections 3–5, not
something to invent here.

Follow this repo's `ios-engineering` conventions throughout: DTOs mirror the wire format exactly
and stay separate from domain models (per `ios-engineering/references/swift-codable-designer.md`),
networking is layered as Endpoint/Client/Service (per
`ios-engineering/references/ios-networking.md`), persistence defaults to SwiftData
(per `ios-engineering/references/swiftdata-schema-designer.md`), and the app layer defaults to
MVVM unless `ios-engineering`'s own architecture-choice section says otherwise for this codebase.

A TDD's core sections are written in backend-service shape (API endpoints, DB tables, service
layers). For an iOS client, that maps as: **section 3 (API Contract)** is the contract this app
*consumes*, not serves — this appendix's Networking Layer subsection shows the client-side
signatures for it. **Section 4 (Data Model)** maps to local persistence when this feature caches
or stores data on-device — this appendix's Persistence Layer subsection shows the `@Model`
declarations for it. If the feature has no backend (purely on-device) or no local persistence,
section 3 or 4 will already say "N/A" — skip the corresponding subsection below entirely rather
than inventing one.

## 1. Networking layer (consuming section 3's API Contract)

- **DTOs**, one per request/response shape in the API Contract, matching the wire format exactly
  (snake_case fields via `CodingKeys` if needed, optionals for anything the server might omit):

  ```swift
  struct OrderResponseDTO: Decodable {
      let id: String
      let status: String
      let createdAt: String
  }
  ```

- **Domain model** the rest of the app actually uses — non-optional where the app requires a
  value, real `URL`/`Date`/enum types — plus the mapping initializer's signature (`init(dto:)` or
  a free mapping function), not its body.
- **Endpoint value** describing the request (method, path, query, headers, body), per
  `ios-networking.md`'s Endpoint/Client/Service split:

  ```swift
  struct CreateOrderEndpoint: Endpoint {
      let payload: OrderCreateDTO
      var path: String { "/orders" }
      var method: HTTPMethod { .post }
  }
  ```

- **Service method signature** — the domain-level async method other app code actually calls,
  returning the domain model, not the DTO:

  ```swift
  func createOrder(_ input: OrderCreateInput) async throws -> Order
  ```

- **Error handling note** — which of the three failure families (transport/HTTP/decoding, per
  `ios-networking.md`) this endpoint's error responses in section 3 map to; don't collapse them
  into one generic error case.

## 2. Persistence layer (local caching/storage for section 4's Data Model)

- **`@Model` declarations**, one per entity the Data Model section describes needing local
  storage — stored properties only, no business logic on the model itself.
- **Relationships** — `@Relationship` with an explicit delete rule (`.cascade`/`.nullify`/`.deny`)
  for every relationship the Data Model section names; never leave a delete rule at the implicit
  default.
- **Fetching signature** — `@Query` for SwiftUI-driven lists, or a `ResultsObserver`-based method
  signature for non-SwiftUI observation (view model, background sync), per
  `swiftdata-schema-designer.md`. Don't produce both for the same data — pick the one the
  feature's UI actually needs.
- **Migration note** — if this feature changes an existing `@Model`'s shape rather than adding a
  new one, name the `VersionedSchema` step this would require; "N/A" for a purely additive model.

## 3. App layer (translating section 5's Service Design)

- **View model method signatures** — `@Observable` view model methods that call the Service
  methods above and expose state to the view, matching whatever architecture
  (`ios-service-generator.md`'s architecture-choice section) this codebase actually uses — MVVM
  by default, but don't assume it if the detected codebase uses MV/TCA/VIPER instead.
- **State shape** — the properties a view would bind to (loading/error/data states), not the
  view itself.

## When to skip sections

| Skip | When |
|---|---|
| Networking layer | Section 3 (API Contract) is "N/A" — feature is purely on-device |
| Persistence layer | Section 4 (Data Model) is "N/A", or the feature only reads data an existing model already covers |
| Migration note | New `@Model` is purely additive, no shape change to an existing one |
| App layer | Feature is backend-only with no iOS client surface (unusual for this appendix to be loaded at all in that case) |

## Quality checklist

- [ ] Every DTO matches a request/response shape actually named in the TDD's API Contract — no
      invented fields
- [ ] Domain model and DTO are kept separate — no single type serving both roles unless that's an
      explicit, stated decision
- [ ] Every relationship's delete rule is stated explicitly, never left implicit
- [ ] Error handling note assigns each API error to one of the three failure families, not a
      generic catch-all
- [ ] No method bodies — every signature is a stub, nothing is actually implemented
