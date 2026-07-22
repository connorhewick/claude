# Spring Boot Service Generator

Scaffold layered Spring Boot services end to end — controller through entity — with interface-first DI, immutable record DTOs, and validation at the API boundary.

---

## Overview

A production Spring Boot service is a strict, one-directional stack: controller → DTO → service interface → service implementation → repository → entity, each layer depending only on the one below it. The philosophy is separation of concerns made structural rather than aspirational — the API contract (DTOs) is decoupled from the persisted schema (entities) so either can change without breaking the other, service consumers depend on an interface so implementations are swappable and mockable, and every write path runs through Bean Validation before any business logic sees it. This reference covers both the layer scaffold itself and the DTO design that sits at its API boundary — the two are inseparable in practice, since most scaffolding work is "add an entity" and "design its DTO family" happening together.

## Core Concepts

**Dependencies point one direction, always.** Controllers depend on service interfaces; services depend on repositories and other services; repositories depend on entities. Controllers never touch repositories directly, services never depend on controllers, and entities never contain business logic. A shortcut that crosses this compass is a design smell to flag, not a convenience to take.

**Controllers are thin and type-hinted against interfaces, not implementations.** A controller's job is HTTP in, HTTP out: `@Valid` on the request body, constructor-injected service interface, and a return type that's always a DTO — never an entity. Business logic that creeps into a controller method is logic that belongs one layer down.

**Services split into interface and implementation, and the interface is the contract everything else depends on.** The interface defines the operation signatures; the implementation carries `@Transactional` on writes, `@Cacheable`/`@CacheEvict` on reads/writes, and the actual business logic. This split is what makes a service mockable by interface in tests and swappable without touching callers — not ceremony for its own sake.

**Repositories are declarative; let Spring generate the SQL.** Extend `JpaRepository<T, ID>` and express queries as derived method names or `@Query` JPQL — see `jpa-query-patterns.md` for the full pattern set (EntityGraph, Specifications, bulk operations, pagination). A repository returns entities or projections; it never makes a business decision.

**Entities are data, never logic, and money is always `BigDecimal`.** `@Entity` classes hold `@Column`/`@JoinColumn`/relationship mappings and nothing else — no validation, no business rules, no formatting. Monetary fields are always `BigDecimal`, never `Double`/`Float`, because binary floating point cannot represent decimal currency exactly and the rounding error compounds silently across calculations.

**DTOs form a family, one record per direction across the API boundary.** A single "universal" DTO used for both request and response inevitably leaks internal fields into responses or makes partial updates ambiguous. Separate records per direction: `{Entity}CreateDTO` (all fields required, heavily validated), `{Entity}UpdateDTO` (all fields nullable — genuinely partial PATCH semantics), `{Entity}ResponseDTO` (server-generated fields, no validation — it's already-trusted data), and `{Entity}FilterDTO` (query parameters for list/search endpoints, its own validation for ranges and enums). Records are immutable by construction — no setters exist to accidentally mutate a DTO after validation has already run against it.

**Records validate structurally at construction; Bean Validation validates semantically at the edge.** A record's compact constructor runs before any field is assigned and is the right place for normalization (trimming, case-folding) or invariants that Bean Validation annotations can't express cleanly (e.g., "this BigDecimal must not exceed 2 decimal places"). Bean Validation (`@NotNull`, `@DecimalMin`, custom `@Constraint` types) stays the primary validation layer at the controller boundary via `@Valid` — the compact constructor is a defense-in-depth complement for structural rules, not a replacement for annotation-driven validation, and it should never duplicate what an annotation already checks.

**Polymorphic payloads are sealed, not stringly-typed.** Where a field can be one of several shapes (multiple notification types, multiple event types), a `sealed interface` with Jackson's `@JsonTypeInfo`/`@JsonSubTypes` for the discriminator gives compile-time exhaustiveness — a `switch` over the sealed type fails to compile when a new subtype is added and not handled. This replaces an untyped `Object` field plus `instanceof` chains, which the compiler cannot check for completeness.

**Mapping between entity and DTO is generated, not hand-rolled.** A hand-written `toDTO()`/`toEntity()` pair on every entity is boilerplate that silently drifts as fields are added. MapStruct generates a compile-time mapper from an interface declaration; `NullValuePropertyMappingStrategy.IGNORE` on the update-mapping method is what makes a `PATCH` genuinely partial — null fields in the `UpdateDTO` leave the corresponding entity fields untouched.

**A single exception-handling layer converts domain exceptions to HTTP status codes.** Services throw domain exceptions (`EntityNotFoundException`, not an HTTP status); one `@RestControllerAdvice` maps them centrally. This keeps the mapping from exception to status code in exactly one place instead of scattered `try/catch` blocks across controllers.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| How does a controller depend on a service? | By interface, constructor-injected | Mockable in tests, swappable implementation, no field injection |
| One DTO or several, per entity? | Separate Create/Update/Response(/Filter) records | A universal DTO leaks fields into responses and makes partial updates ambiguous |
| Where does structural DTO validation belong (trimming, precision)? | The record's compact constructor | Runs before field assignment; complements Bean Validation, doesn't replace it |
| Where does semantic validation belong (`@NotNull`, ranges)? | Bean Validation annotations + `@Valid` at the controller | Rejected before the method body runs; centralizes the rule instead of scattering `if` checks |
| A field can be one of several distinct shapes? | `sealed interface` + `@JsonTypeInfo`/`@JsonSubTypes`, not `Object` | Compiler-enforced exhaustive handling; a new subtype breaks every non-exhaustive `switch` |
| Entity ↔ DTO conversion? | A MapStruct mapper interface | Compile-time generated, no reflection, doesn't drift silently like hand-written mapping |
| Multiple entities share timestamp/soft-delete fields? | `@MappedSuperclass` | Shared columns without forcing a shared table or JPA inheritance strategy |
| Multiple implementations of one service contract? | Interface + `@Primary`/`@Qualifier` to disambiguate | Keeps the interface the single point every caller depends on |
| Read path caching? | `@Cacheable(key = "#id", unless = "#result == null")` | Explicit key and null-guard avoid caching a miss as if it were a hit |

## Workflow

1. **Run project discovery** (see the router `SKILL.md`) if not already done this session — Spring Boot/Java version, existing layer conventions, migration tool.
2. **Design the entity** — JPA annotations, relationships, `@MappedSuperclass` for shared audit fields, `BigDecimal` for any monetary field.
3. **Design the DTO family** — Create (required + validated), Update (all nullable), Response (server-only fields), Filter (query semantics) — add compact-constructor normalization only where Bean Validation can't express the rule.
4. **Define the service interface**, then implement it — constructor-injected repository/collaborators, `@Transactional` on writes, `@Cacheable`/`@CacheEvict` on reads/writes.
5. **Define the repository** — `JpaRepository<T, ID>` plus derived/`@Query` methods; consult `jpa-query-patterns.md` for anything beyond simple CRUD.
6. **Define the controller** — constructor-injected service interface, `@Valid` on the request body, DTOs only in the signature.
7. **Wire exception handling** — add new domain exceptions to the shared `@RestControllerAdvice` if needed; never let a controller construct an HTTP status itself.
8. **Add a MapStruct mapper** for the entity ↔ DTO family, with `NullValuePropertyMappingStrategy.IGNORE` on the update method.
9. **Instrument logging** at the service/controller boundary — see `slf4j-logback-instrumentation.md`.
10. **Write tests** — service unit test, controller slice test, repository test if a non-trivial query was added — see `junit-mockito-patterns.md`.
11. **Self-review against the Quality Checklist** below before calling the layer complete.

## Patterns

### Layer skeleton

```java
// Controller — thin, interface-typed, DTOs only
@RestController
@RequestMapping("/orders")
public class OrderController {
    private final OrderService orderService;               // interface, not impl
    public OrderController(OrderService orderService) { this.orderService = orderService; }

    @PostMapping
    public ResponseEntity<OrderResponseDTO> create(@Valid @RequestBody OrderCreateDTO request) {
        return ResponseEntity.status(201).body(orderService.create(request));
    }
}

// Service interface — the contract
public interface OrderService {
    OrderResponseDTO create(OrderCreateDTO request);
    Optional<OrderResponseDTO> findById(Long id);
}

// Service implementation — logic, transactions, caching, logging
@Service
@Slf4j
public class OrderServiceImpl implements OrderService {
    private final OrderRepository repository;
    private final OrderMapper mapper;
    public OrderServiceImpl(OrderRepository repository, OrderMapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }

    @Override
    @Transactional
    public OrderResponseDTO create(OrderCreateDTO request) {
        log.atInfo().addKeyValue("customerId", request.customerId()).log("Creating order");
        Order saved = repository.save(mapper.toEntity(request));
        return mapper.toResponse(saved);
    }

    @Override
    @Cacheable(value = "orders", key = "#id", unless = "#result == null")
    public Optional<OrderResponseDTO> findById(Long id) {
        return repository.findById(id).map(mapper::toResponse);
    }
}

// Repository — declarative, see jpa-query-patterns.md for anything non-trivial
public interface OrderRepository extends JpaRepository<Order, Long> {
    List<Order> findByCustomerId(Long customerId);
}

// Entity — data only; BigDecimal for money
@Entity
@Table(name = "orders")
public class Order {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false)
    private Long customerId;
    @Column(nullable = false)
    private BigDecimal totalPrice;          // never Double/Float
    @CreationTimestamp
    private LocalDateTime createdAt;
}
```

### DTO family: compact constructor + nested record + Bean Validation

```java
public record OrderCreateDTO(
    @NotNull @Positive Long customerId,
    @NotEmpty(message = "Order must contain at least one item")
    List<@Valid OrderItemDTO> items,
    @NotNull @DecimalMin("0.01") BigDecimal totalPrice
) {
    public OrderCreateDTO {                       // compact constructor: runs before field assignment
        if (totalPrice != null && totalPrice.scale() > 2) {
            throw new IllegalArgumentException("totalPrice must not exceed 2 decimal places");
        }
    }
}

public record OrderItemDTO(
    @NotNull UUID productId,
    @Positive Integer quantity,
    @DecimalMin("0.01") BigDecimal unitPrice
) {}

public record OrderUpdateDTO(                      // all nullable — genuinely partial PATCH
    @DecimalMin("0.01") BigDecimal totalPrice,
    OrderStatus status
) {}

public record OrderResponseDTO(                     // server-generated; no validation — trusted data
    Long id, Long customerId, BigDecimal totalPrice, OrderStatus status, LocalDateTime createdAt
) {}

public record OrderFilterDTO(                       // query parameters — its own light validation
    OrderStatus status,
    @DecimalMin("0") BigDecimal minTotal
) {}
```

### Custom validator for a rule Bean Validation can't express directly

```java
@Documented
@Constraint(validatedBy = DateRangeValidator.class)
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidDateRange {
    String message() default "End date must be after or equal to start date";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class DateRangeValidator implements ConstraintValidator<ValidDateRange, DateRangeFilter> {
    @Override
    public boolean isValid(DateRangeFilter filter, ConstraintValidatorContext context) {
        if (filter.startDate() == null || filter.endDate() == null) return true;   // null-safe; @NotNull handles requiredness
        return !filter.endDate().isBefore(filter.startDate());
    }
}

@ValidDateRange
public record DateRangeFilter(LocalDate startDate, LocalDate endDate) {}
```

### Sealed interface for a polymorphic payload

```java
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = EmailNotification.class, name = "email"),
    @JsonSubTypes.Type(value = SmsNotification.class, name = "sms")
})
public sealed interface Notification permits EmailNotification, SmsNotification {}

public record EmailNotification(@Email String to, @NotBlank String subject) implements Notification {}
public record SmsNotification(@Pattern(regexp = "^\\+?[0-9]{10,15}$") String phone) implements Notification {}

// Exhaustive switch — adding a new permitted type breaks this at compile time until handled
void send(Notification n) {
    switch (n) {
        case EmailNotification e -> emailClient.send(e.to(), e.subject());
        case SmsNotification s -> smsClient.send(s.phone());
    }
}
```

### MapStruct entity ↔ DTO mapping

```java
@Mapper(componentModel = "spring")
public interface OrderMapper {
    OrderResponseDTO toResponse(Order entity);
    Order toEntity(OrderCreateDTO dto);
    List<OrderResponseDTO> toResponseList(List<Order> entities);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntity(OrderUpdateDTO dto, @MappingTarget Order entity);   // null fields left untouched
}
```

### Global exception handler

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(EntityNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiError("NOT_FOUND", ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        return ResponseEntity.badRequest().body(new ApiError("INVALID_INPUT", ex.getMessage()));
    }
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| API breaks every time a database column changes | `@Entity` exposed directly as the API response | Always map to a Response DTO via MapStruct; never return an entity from a controller |
| PATCH forces clients to resend every field | One DTO reused for both create and update | Separate `UpdateDTO` with all-nullable fields, `NullValuePropertyMappingStrategy.IGNORE` |
| DTO validation logic scattered and inconsistent | Validation performed in the service layer instead of at the boundary | `@Valid` on controller parameters; services trust already-validated input |
| Response DTO leaks an internal field or secret | Fields added to a "universal" DTO without direction-specific review | Response DTOs are hand-curated to what the client needs — not a mirror of the entity |
| A `switch` over a payload type silently misses a case | `Object` + `instanceof` chains instead of a sealed hierarchy | `sealed interface` + exhaustive `switch` — the compiler catches an unhandled case |
| Field injection (`@Autowired` on a field) found in new code | Habit from older Spring conventions | Constructor injection only, with `final` fields |
| Controller directly calls a repository | Layer shortcut for "just this one query" | Route through the service layer; flag and ask before taking a shortcut across the compass |
| Money field drifts by fractions of a cent across calculations | `Double`/`Float` used for a monetary field | `BigDecimal` everywhere money is represented, entity and DTO alike |
| Two `@Service` beans implementing the same interface fail to wire | No `@Primary`/`@Qualifier` to disambiguate | Mark the default implementation `@Primary`, or qualify the injection point explicitly |
| Entity↔DTO mapping drifts as fields are added | Hand-written `toDTO()`/`toEntity()` methods | Generate the mapper with MapStruct; the interface declaration can't silently miss a field forever |

## Quality Checklist

- [ ] Every `@Service`/`@Controller`/`@Repository` uses constructor injection with `final` fields — no field injection
- [ ] Controllers type-hint against service interfaces, never the implementation class
- [ ] DTO family present per direction (Create/Update/Response, Filter if the entity is listable) — no single DTO shared across directions
- [ ] Compact constructors used only for structural rules Bean Validation can't express — not duplicating an existing annotation
- [ ] `@Valid` present on every controller parameter that accepts a Create/Update/Filter DTO
- [ ] No `@Entity` ever returned directly from a controller method
- [ ] Polymorphic payload fields use a `sealed interface` with a Jackson discriminator, not `Object`
- [ ] A MapStruct mapper exists for each entity↔DTO family, with `NullValuePropertyMappingStrategy.IGNORE` on the update method
- [ ] All monetary fields are `BigDecimal`, entity and DTO alike
- [ ] Writes are `@Transactional`; reads use `@Cacheable` with an explicit key and `unless` null-guard where caching applies
- [ ] A single `@RestControllerAdvice` maps every domain exception to an HTTP status — no ad hoc `try/catch` in controllers
- [ ] `@Slf4j` logging present at service and controller boundaries (see `slf4j-logback-instrumentation.md`)
- [ ] Non-trivial repository queries follow `jpa-query-patterns.md` rather than ad hoc `@Query` strings
- [ ] Unit and slice tests exist for the new service/controller/repository (see `junit-mockito-patterns.md`)
