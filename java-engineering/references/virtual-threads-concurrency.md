# Virtual Threads & Structured Concurrency

Java's modern concurrency model for I/O-heavy Spring Boot services: virtual threads, structured concurrency, scoped values, and where `CompletableFuture` still earns its keep.

---

## Overview

Since Java 21, virtual threads let a service handle very high I/O-bound concurrency with ordinary blocking code — no reactive rewrite required. Of the two APIs that shipped alongside them as preview features, only one has actually finalized: **scoped values are standard as of JDK 25** (JEP 506, no flag needed). **Structured concurrency is still in preview** — JDK 25 carries its fifth preview (JEP 505, which reworked the API to a `StructuredTaskScope.open(Joiner)` factory instead of subclassing `ShutdownOnFailure`/`ShutdownOnSuccess`), and a sixth preview (JEP 525) is already targeting JDK 26. Both still require `--enable-preview` at compile and run time, and the exact `Joiner` surface has changed release to release — treat any structured-concurrency code sample, including the one below, as needing a check against the JDK you're actually building against, not as a stable contract yet. The core philosophy: match the concurrency model to how the workload actually blocks — blocking I/O wants virtual threads, sub-10ms-latency workloads want reactive, and CPU-bound parallelism wants neither. Getting this decision right up front avoids both the reactive-everywhere over-engineering of the last decade and the naive over-threading it replaced.

## Core Concepts

**Virtual threads are cheap, JVM-scheduled, and unmount on blocking I/O.** Where a platform thread costs ~1MB and ~100µs to create and is scheduled by the OS, a virtual thread costs ~1KB and ~1µs and is scheduled by the JVM atop a small pool of carrier (platform) threads. The JVM scheduler unmounts a virtual thread from its carrier the moment it blocks on I/O, freeing the carrier to run another virtual thread — this is what lets a few carrier threads serve tens of thousands of concurrent blocking requests. Existing blocking code (JDBC, a blocking HTTP client) works unchanged; virtual threads are a deployment/scheduling change, not a rewrite.

**Pinning defeats the entire benefit, and it's caused by a small, specific set of things.** A virtual thread pins its carrier — behaves like a full platform thread, blocking the carrier instead of unmounting — inside a `synchronized` block or method, and in rare cases inside certain native/interruptible I/O calls. Under high concurrency, one pinned hot path can serialize every other virtual thread waiting on that carrier, producing a throughput cliff that looks like ordinary lock contention because structurally it is. The fix is mechanical: replace `synchronized` with `ReentrantLock` (or `@Cacheable` for cache-aside reads), which suspends the virtual thread without pinning the carrier while it waits.

**Structured concurrency makes a task tree's lifetime explicit and enforces it — but it's still a preview API.** `StructuredTaskScope` forks child tasks inside a `try`-with-resources block; the scope does not return control to the caller until every child has completed, failed, or been cancelled, and `scope.close()` guarantees no forked task outlives the block. As of JEP 505 (JDK 25's fifth preview), the scope is opened via `StructuredTaskScope.open(Joiner)` rather than subclassing `ShutdownOnFailure`; a `Joiner` such as `allSuccessfulOrThrow()` propagates cancellation to every sibling the moment one task fails — the concurrent equivalent of a function that can't return until all its work is actually done, replacing hand-rolled `CompletableFuture` graphs where the tasks share one lifetime and one failure should cancel the rest. Because this is preview API that has changed shape across five rounds of previews (JEP 428→437→453→462→480→499→505, with a sixth, JEP 525, already targeting JDK 26), confirm the exact `Joiner` factory methods against the javadoc of the JDK you're building against before shipping.

**Scoped values replace `ThreadLocal` for context that must reach child virtual threads.** `ThreadLocal` is mutable, requires manual `.remove()` cleanup, and does not propagate to a child virtual thread spawned from within a scope — SLF4J's MDC hits exactly this limitation (see `slf4j-logback-instrumentation.md`). `ScopedValue.where(key, value).run(...)` binds an immutable value for the dynamic extent of that call and automatically propagates it to structured children forked inside it, with no leak risk since there's no mutable slot to forget to clear.

**`CompletableFuture` is for integrating non-blocking APIs, not for orchestrating blocking work under virtual threads.** If every step in a chain is a blocking call, running it under a virtual thread with ordinary sequential/structured code is simpler to read, debug, and stack-trace than the same logic expressed as `thenCompose`/`thenCombine`. Reach for `CompletableFuture` composition specifically where a genuinely non-blocking API (a reactive client, an async driver) is already in the mix, or where `orTimeout`/`exceptionally` are the cleanest way to bound and translate a single external call's failure mode.

**The concurrency-model choice is a per-workload decision, not a framework-wide one.** Blocking I/O with a latency budget above roughly 10ms P99 is the sweet spot for virtual threads — simplest code, scales to very high concurrency. Sub-10ms P99 targets generally need Spring WebFlux/Project Reactor with genuinely non-blocking I/O end to end (R2DBC, async HTTP clients) — virtual threads don't help if the latency budget doesn't tolerate any unmount/remount overhead. CPU-bound parallelism (batch transforms, data processing) wants `ForkJoinPool`/parallel streams, not virtual threads — virtual threads solve a blocking-I/O problem, not a not-enough-cores problem.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Code is blocking (JDBC, blocking HTTP), latency budget >~10ms P99? | Virtual threads (`spring.threads.virtual.enabled=true`) | Simplest model; scales to very high I/O concurrency with unchanged code |
| Latency budget is sub-10ms P99? | Spring WebFlux + Project Reactor, fully non-blocking I/O | Every unmount/remount and scheduling hop costs time a strict SLA can't spend |
| Workload is CPU-bound (batch transforms, data processing)? | `ForkJoinPool` / parallel streams | Virtual threads solve blocking I/O, not insufficient CPU parallelism |
| Multiple independent async steps share one lifetime and one failure should cancel the rest? | `StructuredTaskScope.open(Joiner.allSuccessfulOrThrow())` — preview, `--enable-preview` required | Explicit parent-child lifetime, automatic cancellation propagation, guaranteed cleanup |
| Integrating a genuinely non-blocking API, or need `orTimeout`/`exceptionally` on one external call? | `CompletableFuture` composition | The one case where its complexity buys something structured code can't express as directly |
| Context (request ID, tenant) must reach child virtual threads? | `ScopedValue` for new code; `TaskDecorator`-propagated MDC where SLF4J is already in play | Immutable, auto-propagating, no manual cleanup — see `slf4j-logback-instrumentation.md` |
| A hot path holds a `synchronized` block under virtual threads? | Replace with `ReentrantLock` or `@Cacheable` | `synchronized` pins the carrier thread; `ReentrantLock` suspends without pinning |
| Sizing a virtual-thread-backed executor? | Cap conservatively (tens–hundreds, not unbounded) even though VTs are cheap | Unbounded creation still exhausts downstream resources (DB connections, memory) |

## Workflow

1. **Classify the workload** using the Decision Framework: blocking I/O, CPU-bound, or sub-10ms latency — this determines whether virtual threads apply at all.
2. **Enable virtual threads** (`spring.threads.virtual.enabled=true`) if the workload qualifies; no controller/service code changes are required for existing blocking calls.
3. **Audit for `synchronized`** in any code path virtual threads will run through — hot paths especially. Replace with `ReentrantLock` or `@Cacheable`.
4. **Verify with pinning traces** (`-Djdk.tracePinnedThreads=short`) under a representative load test before shipping — don't assume the audit caught everything.
5. **Design multi-step async orchestration with `StructuredTaskScope`** when several calls share a lifetime; reach for `CompletableFuture` only at a genuinely non-blocking-API boundary. It's still preview API (`--enable-preview` at compile and run time) — confirm the `Joiner` signature against the target JDK's javadoc, since it has changed shape across five preview rounds already.
6. **Propagate context explicitly** — `ScopedValue` for new call chains, `TaskDecorator`-based MDC propagation wherever SLF4J logging needs to cross into async/virtual-thread work.
7. **Size the executor conservatively** even though virtual threads are individually cheap — the real constraint is almost always a downstream resource (connection pool, external API rate limit), not thread count.
8. **Load-test and verify** against the Quality Checklist below: throughput/latency under load, zero pinning traces, MDC/context correctly propagated.

## Patterns

### Enabling virtual threads (Spring Boot)

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

Controllers and services run unchanged — existing blocking JDBC/HTTP calls unmount the virtual thread during I/O waits with no code changes.

### Avoiding pinning: `ReentrantLock` instead of `synchronized`

```java
// PINS the carrier thread — every other virtual thread on it stalls
public synchronized OrderResponse getOrder(Long id) {
    return repository.findById(id).orElseThrow();
}

// Does NOT pin — the virtual thread suspends cleanly while waiting for the lock
private final ReentrantLock lock = new ReentrantLock();
public OrderResponse getOrder(Long id) {
    lock.lock();
    try {
        return repository.findById(id).orElseThrow();
    } finally {
        lock.unlock();
    }
}
```

### Detecting pinning under load

```bash
java -Djdk.tracePinnedThreads=short -Dspring.threads.virtual.enabled=true -jar application.jar
```

```
<pinned>, tid: 0x19, <no native frames>
  at com.example.OrderService.getOrder(OrderService.java:42)
```

### Per-resource lock with cache-aside (fine-grained, VT-safe)

**Do not "clean up" the lock map with a `hasQueuedThreads()` check — it's a race, not an optimization.** Thread A can observe no queued waiters and proceed to remove its entry while thread B has *already* fetched that same lock via `computeIfAbsent` and is about to lock it; A then removes the entry out from under B, and a subsequent thread C creates a *new* `ReentrantLock` for the same key and runs concurrently with B — the exact mutual exclusion this pattern exists to provide is gone. Accept unbounded map growth (bounded by the number of distinct product IDs ever requested, which is a fixed, known set in most domains) as the simpler, correct trade-off; if the key space is unbounded, reach for a proven striped-lock implementation (e.g. Guava's `Striped.lock(n)`) instead of hand-rolling reference counting.

```java
@Service
public class ProductService {
    private final ConcurrentHashMap<Long, ReentrantLock> locksByProductId = new ConcurrentHashMap<>();

    public ProductResponse getProduct(Long id) {
        ProductCache cached = getFromCache(id);
        if (cached != null) return cached.toResponse();

        ReentrantLock lock = locksByProductId.computeIfAbsent(id, k -> new ReentrantLock());
        lock.lock();
        try {
            cached = getFromCache(id);                 // double-check inside the lock
            if (cached != null) return cached.toResponse();
            Product product = repository.findById(id).orElseThrow();
            putInCache(id, new ProductCache(product));
            return product.toResponse();
        } finally {
            lock.unlock();                              // entry intentionally stays in the map — see above
        }
    }
}
```

### Structured concurrency: fan-out with shared lifetime and cancellation

**Preview API — requires `--enable-preview` at compile and run time on JDK 25 (JEP 505, fifth preview); the `Joiner` surface may still change before finalization.** JEP 505 replaced the earlier `ShutdownOnFailure`/`ShutdownOnSuccess` subclasses with a `StructuredTaskScope.open(Joiner)` factory:

```java
public OrderResponse createOrder(CreateOrderRequest request) throws Exception {
    try (var scope = StructuredTaskScope.open(StructuredTaskScope.Joiner.allSuccessfulOrThrow())) {
        StructuredTaskScope.Subtask<CustomerResponse> customerTask =
            scope.fork(() -> customerClient.getCustomer(request.customerId()));
        StructuredTaskScope.Subtask<List<InventoryCheckResponse>> inventoryTask =
            scope.fork(() -> inventoryClient.checkStock(request.items()));

        scope.join();   // waits for both; throws ExecutionException if either subtask failed

        CustomerResponse customer = customerTask.get();
        List<InventoryCheckResponse> inventory = inventoryTask.get();

        Order saved = orderRepository.save(toEntity(request, customer));
        return toResponse(saved, inventory);
    }   // scope.close() guarantees no forked task outlives this block
}
```

A deadline is applied at the `Callable` level (e.g. an HTTP client timeout) rather than on the scope itself in the current preview shape — don't assume `joinUntil`/timeout methods from an earlier preview round still exist without checking.

### Scoped values: immutable, auto-propagating request context

```java
private static final ScopedValue<String> REQUEST_ID = ScopedValue.newInstance();

@Component
public class RequestIdFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        ScopedValue.where(REQUEST_ID, UUID.randomUUID().toString())
            .run(() -> {
                try { chain.doFilter(req, res); }
                catch (IOException | ServletException e) { throw new RuntimeException(e); }
            });
    }
}

// Any code called within that scope, including forked structured-concurrency children:
public void logCurrentRequest() {
    log.info("Processing request {}", REQUEST_ID.get());   // no manual propagation needed
}
```

### `CompletableFuture` where it still earns its keep: bounding one external call

```java
public CompletableFuture<OrderResponse> getOrderWithTimeout(Long orderId, Duration timeout) {
    return repository.findByIdAsync(orderId)
        .orTimeout(timeout.toMillis(), TimeUnit.MILLISECONDS)
        .exceptionally(ex -> {
            if (ex.getCause() instanceof TimeoutException) {
                throw new ServiceUnavailableException("Order fetch timed out", ex);
            }
            throw new CompletionException(ex);
        });
}
```

### MDC propagation for async/virtual-thread work (see `slf4j-logback-instrumentation.md` for the full config)

```java
@Bean
public AsyncTaskExecutor asyncExecutor(TaskDecorator mdcDecorator) {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setVirtualThreads(true);
    executor.setTaskDecorator(mdcDecorator);   // captures/restores MDC across the hand-off
    executor.setMaxPoolSize(200);               // conservative cap — see Pitfalls
    executor.initialize();
    return executor;
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Throughput collapses under load despite virtual threads enabled | `synchronized` block/method pins the carrier thread | Replace with `ReentrantLock` or `@Cacheable`; verify with `-Djdk.tracePinnedThreads` |
| Async task sees no request/user context | `ThreadLocal` (including MDC) doesn't propagate to a new/child thread | Use `ScopedValue` for new code, or an MDC `TaskDecorator` where SLF4J is in play |
| OOM or JVM crash under sustained load despite "virtual threads are cheap" | Unbounded virtual-thread creation exhausts a downstream resource (DB pool, memory) | Cap the executor conservatively; the constraint is the downstream resource, not thread cost |
| CPU-bound batch job doesn't speed up on virtual threads | Virtual threads solve blocking I/O, not insufficient CPU parallelism | Use `ForkJoinPool`/parallel streams for CPU-bound work instead |
| Hand-rolled `CompletableFuture` graph is unreadable and hard to debug | Multiple blocking-equivalent steps forced into an async-chain shape unnecessarily | Use `StructuredTaskScope` (or plain sequential code on a virtual thread) when nothing is genuinely non-blocking |
| One failed subtask leaves siblings running, wasting resources | Manual `CompletableFuture.allOf` without cancellation wiring | `StructuredTaskScope.open(Joiner.allSuccessfulOrThrow())` cancels siblings automatically on failure |
| Reactive code stalls under a blocking call slipped into it | A blocking call made directly inside a `Mono`/`Flux` chain | `subscribeOn(Schedulers.boundedElastic())` for blocking calls that must stay in a reactive pipeline |
| `StructuredTaskScope` code fails to compile or throws `UnsupportedOperationException` at runtime | Missing `--enable-preview` — it's still a preview feature (JEP 505 in JDK 25, JEP 525 targeting JDK 26), unlike `ScopedValue` which finalized in JDK 25 (JEP 506) | Add `--enable-preview` to both `javac` and `java`, or drop structured concurrency until it finalizes if the project can't ship preview flags to production |
| Code written against an older preview's `ShutdownOnFailure`/`ShutdownOnSuccess` subclasses fails to compile on JDK 25 | JEP 505 replaced subclassing with the `open(Joiner)` factory | Migrate to `StructuredTaskScope.open(Joiner.allSuccessfulOrThrow())` (or another `Joiner` factory) and re-check against the target JDK's javadoc — the shape may move again before final |

## Quality Checklist

- [ ] Virtual threads enabled (`spring.threads.virtual.enabled=true`) only for I/O-bound workloads — not applied blindly project-wide
- [ ] No `synchronized` blocks/methods in any hot path virtual threads run through; `ReentrantLock`/`@Cacheable` used instead
- [ ] Pinning traces (`-Djdk.tracePinnedThreads=short`) reviewed under representative load, not just assumed clean from a code read
- [ ] Context that must reach child tasks uses `ScopedValue` (new code) or an MDC `TaskDecorator` (SLF4J-based code) — not a bare `ThreadLocal`
- [ ] `StructuredTaskScope` used for any fan-out where tasks share a lifetime and one failure should cancel the rest
- [ ] `CompletableFuture` reserved for genuinely non-blocking API integration or single-call timeout/error translation
- [ ] Executors are capped by a conservative pool-size limit, sized against the real downstream constraint (connections, memory), not left unbounded
- [ ] `ScopedValue` usage assumes standard/final status (JDK 25, JEP 506) — no preview flag needed
- [ ] `StructuredTaskScope` usage is treated as preview (JEP 505 in JDK 25, JEP 525 targeting JDK 26): `--enable-preview` is present on both `javac` and `java`, and the `Joiner` factory used has been checked against the target JDK's actual javadoc, not assumed stable from an older preview round or this doc
- [ ] Load test confirms throughput/latency at target concurrency, not just functional correctness
- [ ] CPU-bound work is routed to `ForkJoinPool`/parallel streams, not virtual threads
