# Java Implementation Notes

This appendix translates a finished TDD's API Contract and Data Model sections into concrete
Spring Boot/JPA signatures — **signatures only, no implementations.** Method bodies end in `{ ... }`
or a single `throw new UnsupportedOperationException()`; nothing here is working code. Mirror the
TDD, don't extend it — if this appendix would need content the TDD itself doesn't have, that's a
gap in the TDD's own sections 3–4, not something to invent here.

Follow this repo's `java-engineering` conventions throughout: DTOs are immutable records forming
a `{Entity}CreateDTO`/`{Entity}UpdateDTO`/`{Entity}ResponseDTO`/`{Entity}FilterDTO` family, Bean
Validation at the controller boundary, money as `BigDecimal`, one shared `@RestControllerAdvice`
for exception mapping — see `java-engineering/references/springboot-service-generator.md` for the
full rationale behind these if it's ever unclear which pattern applies.

Load only the subsections below that this feature actually needs — don't produce all four for a
feature that, say, adds no new table.

## 1. Controller & error handling

- **Controller method signatures**, one per API Contract endpoint — constructor-injected service
  interface, `@Valid` on request bodies, DTOs only in the signature (never an entity), explicit
  `@PathVariable`/`@RequestParam`/`@RequestHeader` for every parameter the TDD names:

  ```java
  @RestController
  @RequestMapping("/orders")
  public class OrderController {
      private final OrderService orderService;

      @PostMapping
      public ResponseEntity<OrderResponseDTO> create(@Valid @RequestBody OrderCreateDTO request) { ... }
  }
  ```

- **Error mapping table** — one row per error scenario the TDD's API Contract names:

  | TDD scenario | HTTP status | Exception | Response DTO |
  |---|---|---|---|
  | Resource not found | 404 | `EntityNotFoundException` | `ErrorResponseDTO` |
  | Validation failure | 400 | (handled by Bean Validation) | `ErrorResponseDTO` |
  | Conflict / duplicate | 409 | `ConflictException` | `ErrorResponseDTO` |

- **`@RestControllerAdvice` addition** — the new `@ExceptionHandler` method(s) this feature adds
  to the project's shared advice class, not a second advice class.

## 2. DTOs & entities

- **DTO family** for each new/changed resource — `{Entity}CreateDTO` (all fields required,
  validated), `{Entity}UpdateDTO` (all fields nullable, genuine partial-update semantics),
  `{Entity}ResponseDTO` (server-generated fields included, no validation), `{Entity}FilterDTO`
  (query parameters for list endpoints) — only the members this feature's endpoints actually use.
- **Entity models** — `@Entity` classes holding only `@Column`/`@JoinColumn`/relationship
  mappings, no logic. `@OneToMany`/`@ManyToOne` default to `FetchType.LAZY` unless the TDD's
  Service & UI Design section explicitly justifies eager loading. Money fields are `BigDecimal`,
  never `Double`/`Float`. Add `@Version` for optimistic locking on any entity the TDD's NFR
  section flags as concurrently-written.

## 3. Service & repository

- **Service interface** — one method per operation the TDD's Service & UI Design section names,
  Javadoc'd with any caching/transactional contract the method needs (`@Transactional`,
  `@Cacheable`/`@CacheEvict` if the project already uses a cache layer — don't introduce caching
  a TDD didn't ask for).
- **Repository interface** — Spring Data `JpaRepository` with derived-query method signatures
  (`findByStatusAndCreatedAtBefore(...)`), one per query the Service & UI Design section actually
  needs — no speculative finder methods.

## 4. Migrations & observability

- **Migration stub** — one per new table/column, in whatever migration tool the project already
  uses (Flyway/Liquibase) and whatever SQL dialect its actual database is (don't assume a
  specific vendor — match what Project Discovery found). Explicit ordering note when a new
  table's foreign key points at another new table in the same TDD (create the referenced table
  first).
- **Logging** — name the log points this feature adds (controller entry/exit, service-level
  business events, repository-level slow-query warnings), matching the project's existing SLF4J/
  structured-logging conventions rather than inventing new ones — see
  `java-engineering/references/slf4j-logback-instrumentation.md` if the project has that
  reference installed.
- **Tracing** — if the project has OpenTelemetry wired up, name the span(s) this feature would
  add, following its existing span-naming convention.

## When to skip sections

| Skip | When |
|---|---|
| DTOs & entities | Feature reuses an existing resource's DTOs/entities unchanged |
| Migrations | No new table/column — feature only adds endpoints over existing data |
| Repository | Feature needs no new query beyond what an existing repository method already covers |
| Tracing | Project has no tracing set up yet |

## Quality checklist

- [ ] Every controller signature matches an endpoint in the TDD's API Contract — no invented
      routes
- [ ] DTO family only includes the members this feature's endpoints actually use — no speculative
      fields
- [ ] Every entity relationship's fetch type is stated explicitly (`LAZY` unless justified)
- [ ] Migration ordering is correct for any new-table-to-new-table foreign keys
- [ ] No method bodies — every signature is a stub, nothing is actually implemented
