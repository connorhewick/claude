# JPA Query Patterns

Write Spring Data JPA repository queries that are correct, N+1-free, and composable within a layered service architecture.

---

## Overview

Database queries are usually the dominant source of latency in a web service, and Spring Data JPA has enough surface area that a query can be technically correct while being operationally dangerous — a single N+1 in a list endpoint turns a 50ms response into a 5-second one. The core philosophy: let Spring generate queries whenever possible, declare loading strategy per query rather than on the entity, and treat the repository as a place that answers "how" while the service decides "what" and "why."

## Core Concepts

**Let Spring generate the query before you hand-write one.** Derived query methods (`findByStatusAndCustomerId`) are compile-time checked against the entity's fields and eliminate an entire class of string-based query bugs. Reach for `@Query`/JPQL only when a derived method can't express the shape you need, and reach for native SQL only when JPQL itself can't express the syntax (window functions, database-specific extensions) — native queries forfeit portability and the same compile-time field checking.

**Loading strategy belongs to the query, not the entity.** Hard-coding `FetchType.EAGER` on a relationship means *every* query through that entity pays the join cost, whether it needs the relationship or not — and on a one-to-many or many-to-many, it multiplies into cartesian-product blowups. Declare loading per repository method instead, with `@EntityGraph` (ad hoc or named) or an explicit `JOIN FETCH` in JPQL. Lazy is the correct default on every relationship; the query that needs eager data asks for it explicitly.

**Repositories own queries; services own logic.** A repository method returns entities or a projection — it does not decide what the caller does with them. If a repository method starts branching on business conditions, that logic belongs one layer up.

**Compose filters instead of concatenating them.** Spring Data's `Specification<T>` builds dynamic, testable, reusable predicates that combine with `.and()`/`.or()`; each predicate is a small static method that can be unit-tested in isolation. String-concatenated JPQL for "optional filter" scenarios is both a correctness risk and untestable as a unit.

**Paginate in the database, not in the JVM.** `findAll()` followed by an in-memory `.subList()` still pulls the full table across the wire. Always accept `Pageable` on list-returning methods. Offset pagination (`Pageable`/`PageRequest`) is fine for shallow paging with a known total; keyset (cursor) pagination — filtering on `WHERE createdAt < :cursor ORDER BY createdAt DESC`) is O(1) regardless of how deep the page is and is the only sound choice for "infinite scroll" or deep pagination, since offset pagination's cost grows with the offset.

**Projections skip the ORM tax for read-only views.** Fetching a full entity graph to render three fields in a list view wastes both the query and the object-mapping cost. Interface-based projections (`interface OrderSummary { Long getId(); ... }`) and record-based DTO projections (`SELECT new com.example.OrderDTO(...)`) fetch only the needed columns; prefer a record over a hand-written class for the constructor-expression form — it is the same JPQL, less boilerplate.

**Transactions bound how far lazy loading can reach.** Accessing a lazy relationship after the transaction (and Hibernate session) has closed throws `LazyInitializationException`. Load everything the caller will touch — via `@EntityGraph` or fetch join — before the `@Transactional` boundary ends; don't try to route around it with `OpenSessionInView`, which just defers the same coupling problem into the web layer.

**Bulk operations bypass the persistence context — flush and clear afterward.** A `@Modifying @Query` `UPDATE`/`DELETE` writes directly to the database, so any entity already loaded into the persistence context is now stale. Call `entityManager.flush()` then `entityManager.clear()` immediately after a bulk operation, or a subsequent read in the same transaction will return cached, incorrect state.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Can the query be expressed as a method name? | Derived query method | Compile-time field checking; no string to get wrong |
| Query needs a join, aggregation, or constructor expression? | `@Query` with JPQL | Portable, still parameter-bound, still type-checked against the entity model |
| Query needs database-specific syntax (window functions, etc.)? | Native `@Query` | Only escape hatch when JPQL genuinely can't express it |
| Filters are optional/combinable at runtime? | `Specification<T>` | Composable, unit-testable predicates; no string concatenation |
| Need to declare a relationship's loading strategy? | `@EntityGraph` (ad hoc or named) per method | Keeps `FetchType` lazy on the entity; avoids blanket eager loading |
| List endpoint, shallow pages, need a total count? | `Pageable`/`Page<T>` | Simple, and the total count is genuinely useful at shallow depth |
| Infinite scroll or deep pagination? | Keyset (cursor) pagination | O(1) cost regardless of page depth; offset pagination degrades linearly |
| Read-only view, only a few columns needed? | Interface or record projection | Skips full entity hydration and the ORM mapping cost |
| Mass update/delete across many rows? | `@Modifying @Query`, then `flush()` + `clear()` | Bypasses per-row entity loading; clears stale persistence-context state |

## Workflow

1. **Identify the data need** — which entity, which filters, which relationships the caller will actually touch.
2. **Choose the query method** — derived method first, `@Query`/JPQL next, `Specification` for dynamic filters, native SQL only as a last resort.
3. **Declare the loading strategy explicitly** — `@EntityGraph`, `@BatchSize`, or `JOIN FETCH`; never rely on the entity's default `FetchType`.
4. **Handle pagination** — `Pageable` for standard lists, keyset for deep/infinite pagination, `Slice<T>` when you only need "is there a next page," not a total count.
5. **Choose the return type** — full entity only if the caller mutates it; otherwise a projection or DTO.
6. **Review for anti-patterns** — especially `FetchType.EAGER`, lazy access outside a transaction, and `entityManager.find()` in a loop.
7. **Verify** — run with Hibernate SQL statistics enabled (or an assertion library that counts queries) to confirm the expected number of round trips, not just that the test passes.

## Patterns

### Derived queries and JPQL

```java
public interface OrderRepository extends JpaRepository<Order, Long> {
    List<Order> findByCustomerId(Long customerId);
    List<Order> findByStatusOrderByCreatedAtDesc(OrderStatus status);
    Page<Order> findByCustomerId(Long customerId, Pageable pageable);
    Optional<Order> findByIdAndCustomerId(Long id, Long customerId);
}

@Query("""
    SELECT o FROM Order o
    JOIN FETCH o.customer c
    WHERE o.status = :status
    ORDER BY o.createdAt DESC
    """)
List<Order> findByStatusWithCustomer(@Param("status") OrderStatus status);
```

### EntityGraph: ad hoc, named, and nested

```java
public interface OrderRepository extends JpaRepository<Order, Long> {
    @EntityGraph(attributePaths = {"customer"})
    List<Order> findByStatus(OrderStatus status);

    @EntityGraph(attributePaths = {"customer", "products.category"})   // nested path
    List<Order> findByStatusOrderByCreatedAtDesc(OrderStatus status);

    @EntityGraph("OrderWithCustomerAndProducts")                      // named graph
    Optional<Order> findById(Long id);
}

@Entity
@NamedEntityGraph(name = "OrderWithCustomerAndProducts", attributePaths = {"customer", "products"})
public class Order {
    @ManyToOne(fetch = FetchType.LAZY)
    private Customer customer;

    @OneToMany(fetch = FetchType.LAZY, mappedBy = "order")
    @BatchSize(size = 25)                                             // batches lazy loads instead of N+1
    private List<OrderItem> items;
}
```

### Specifications for dynamic, composable filters

```java
public class OrderSpecifications {
    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> status == null ? null : cb.equal(root.get("status"), status);
    }
    public static Specification<Order> createdAfter(LocalDateTime date) {
        return (root, query, cb) -> date == null ? null : cb.greaterThan(root.get("createdAt"), date);
    }
}

public interface OrderRepository extends JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {}

// Service:
Specification<Order> spec = Specification.where(hasStatus(filter.status()))
    .and(createdAfter(filter.since()));
Page<Order> results = orderRepository.findAll(spec, pageable);
```

### Bulk operations: flush and clear after

```java
public interface OrderRepository extends JpaRepository<Order, Long> {
    @Modifying
    @Transactional
    @Query("UPDATE Order o SET o.status = :status WHERE o.createdAt < :before")
    int bulkUpdateStatus(@Param("status") OrderStatus status, @Param("before") LocalDateTime before);
}

@Transactional
public void expireStaleOrders() {
    orderRepository.bulkUpdateStatus(OrderStatus.EXPIRED, LocalDateTime.now().minusDays(30));
    entityManager.flush();
    entityManager.clear();          // invalidate persistence-context state made stale by the bulk write
}
```

### Pagination, keyset pagination, and projections

```java
// Offset pagination — fine for shallow pages
Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
Page<Order> page = orderRepository.findByCustomerId(customerId, pageable);

// Keyset pagination — O(1) regardless of depth; use for infinite scroll / deep paging
@Query("""
    SELECT o FROM Order o
    WHERE o.customerId = :customerId AND o.createdAt < :cursor
    ORDER BY o.createdAt DESC
    """)
List<Order> findByCustomerAfterCursor(@Param("customerId") Long customerId,
                                       @Param("cursor") LocalDateTime cursor, Pageable pageable);

// Interface projection — only the columns it declares are fetched
public interface OrderSummary {
    Long getId();
    OrderStatus getStatus();
    BigDecimal getTotalPrice();
}

// Record projection via constructor expression — prefer this over a hand-written class
public record OrderDTO(Long id, OrderStatus status, BigDecimal totalPrice, LocalDateTime createdAt) {}

@Query("""
    SELECT new com.example.ordersystem.dto.OrderDTO(o.id, o.status, o.totalPrice, o.createdAt)
    FROM Order o WHERE o.customerId = :customerId
    """)
List<OrderDTO> findDTOsByCustomerId(@Param("customerId") Long customerId);
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| List endpoint fans out into hundreds of queries | Lazy relationship accessed in a loop with no declared loading strategy | Declare `@EntityGraph`/`JOIN FETCH`/`@BatchSize` on the repository method |
| Every query through an entity is slow, even ones that don't need the relationship | `FetchType.EAGER` on a `@OneToMany`/`@ManyToMany` | Set `FetchType.LAZY` on the mapping; load eagerly per-query instead |
| `LazyInitializationException` outside a request/service method | Lazy relationship touched after the transaction closed | Fetch what's needed inside `@Transactional`, via `@EntityGraph`/fetch join |
| Read-only list endpoint is slow despite a good query plan | Fetching full entities (and their relationships) for a view that needs 3 fields | Return an interface or record projection instead |
| Bulk update "didn't take effect" in the same request | Persistence context still holds pre-update entity state | `entityManager.flush()` + `.clear()` immediately after the bulk `@Modifying` call |
| N queries for N IDs | `entityManager.find()` (or a repository call) inside a loop | Use `findAllById(ids)` or an `IN` clause |
| Deep pagination gets progressively slower | Offset (`OFFSET`/`LIMIT`) pagination at high page numbers | Switch to keyset (cursor-based) pagination for deep or infinite-scroll lists |
| Dynamic filter query is untestable and fragile | Filters built by string concatenation | Use `Specification<T>` with small, independently testable predicate methods |

## Quality Checklist

- [ ] No `FetchType.EAGER` on any one-to-many or many-to-many relationship
- [ ] Every list-returning repository method accepts `Pageable` — no unbounded `findAll()` on a large table
- [ ] Every relationship touched by a query has an explicit loading strategy (`@EntityGraph`, `@BatchSize`, or `JOIN FETCH`)
- [ ] Bulk `@Modifying` operations are followed by `entityManager.flush()` + `.clear()`
- [ ] Read-only views return a projection (interface or record) rather than a full entity
- [ ] Dynamic filters use `Specification` or a custom repository fragment — no string-concatenated JPQL
- [ ] `@Transactional` is present on service methods that touch lazy relationships, and on `@Modifying` repository methods
- [ ] Deep-pagination or infinite-scroll endpoints use keyset pagination, not offset
- [ ] N+1 is verified absent via Hibernate SQL statistics or a query-count assertion in tests, not assumed
- [ ] `@Query` methods use `@Param` binding — never string concatenation
