# Java Performance Optimization

A measurement-first framework for profiling, diagnosing, and fixing performance problems in Java/Spring Boot services — from algorithmic bottlenecks down to JVM tuning.

---

## Overview

Performance work in Java fails most often not from picking the wrong fix, but from picking a fix before knowing the problem. This reference is a six-step loop — understand, profile, identify, fix, benchmark, document — wrapped around an optimization hierarchy: algorithmic and architectural changes dominate (10–1000x), JVM tuning is a distant second (1.5–3x), and CPU micro-tuning is last and smallest (1.1–2x). The philosophy: profile first, fix the widest block in the flamegraph, and never let JVM-tuning instincts substitute for looking at what the code actually does.

## Core Concepts

**Never optimize without a measurement.** A baseline (latency, throughput, memory, GC pause) turns "this feels slow" into a target you can hit and prove you hit. Optimizing blind wastes effort on non-bottlenecks and risks introducing bugs for no measurable gain.

**The optimization hierarchy determines where effort pays off.** Algorithm and query changes (O(n²)→O(n log n), eliminating N+1, adding a cache) yield the largest wins and should be addressed first — profiling almost always reveals them. Architecture changes (read replicas, async batching, connection pooling) come next. JVM runtime tuning (GC, JIT warm-up) is a multiplier on top of a sound design, not a substitute for one. CPU micro-tuning (lock-free structures, branch-prediction-friendly code) is worth reaching for only after a profiler proves it's the remaining bottleneck — it rarely is.

**Bottleneck categories dictate which tool to reach for.** Latency problems want a JFR timeline or async-profiler CPU flamegraph. Throughput problems want JMH or load-test metrics. Memory pressure wants a heap dump. GC pause spikes want the GC log (`-Xlog:gc*`). Lock contention shows up as `BLOCKED` threads in a thread dump or JFR's contention profiler. I/O blocking shows as "waiting" time in the profiler, not CPU time — conflating the two leads to tuning the wrong axis entirely.

**JFR and async-profiler are complementary lenses, not competitors.** JFR is built into the JDK, near-zero overhead, and best for CPU/GC/lock-contention correlation over a production-representative window. async-profiler produces sharper flamegraphs for visual hotspot hunting. JMH exists to answer a narrower question — "is change A faster than change B" — with statistical rigor a stopwatch can't provide; use it to validate a micro-optimization, not to find the bottleneck in the first place.

**Virtual threads change the concurrency profile, not the algorithm underneath it.** They multiplex I/O-bound work cheaply, but a `synchronized` block still pins the carrier thread and defeats the scheduler — under load this shows up as throughput cliffs that look like lock contention because that's exactly what it is. See `virtual-threads-concurrency.md` for the full pinning-detection and avoidance treatment; here it matters only as a bottleneck category to recognize.

**Connection pools are sized from I/O wait time, not from a round number.** HikariCP's default sizing formula (`(core count × 2) + effective disk spindles`) reflects that each connection blocks on I/O most of its life — cores should idle 50–70% of the time waiting on the database. Oversizing wastes memory and can make the database itself the bottleneck under contention; undersizing manifests as connection-timeout errors that look like a database problem but are really a pool problem.

**Startup cost is a separate optimization axis from steady-state throughput.** A service tuned for peak request latency can still have a 3-second cold start that fails a serverless SLA. `@Lazy` beans, conditional bean loading, and (for the strictest cold-start budgets) GraalVM native image compilation trade dynamic flexibility for startup speed — treat this as its own measurement with its own target, not a side effect of runtime tuning.

**GC pause time is tunable independently of heap size, up to a point.** G1 is the sane general-purpose default (~50ms target pause). ZGC targets sub-10ms pauses; since JDK 21 its generational mode is the default and, as of JDK 23, its only mode — it narrows the throughput gap with G1 while keeping pause times flat regardless of heap size. Shenandoah offers similar latency with a different trade-off in memory overhead. Full GC events are the signal to act — increase heap or fix a retention leak, not just tune flags.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Is P99 latency over target and I/O-bound (DB, external API)? | Optimize queries / add caching / async batching first | Algorithmic fixes yield 10–1000x; JVM tuning yields 1.5–3x on top of that at best |
| Is it a high-throughput batch job, not latency-sensitive? | Increase pooling / parallelism, optimize the algorithm | Batch jobs are throughput-bound; latency-oriented GC tuning doesn't apply |
| Is GC pause time over 10ms and it matters (interactive SLA)? | Move to ZGC (generational, default since JDK 21) | Flat pause times independent of heap size; G1's ~50ms target may already miss the SLA |
| Is GC pause acceptable but Full GC events appear in the log? | Increase heap or fix a retention leak, not GC flags | Full GC means the generational hypothesis failed — flag-tuning a symptom won't fix the leak |
| Is the bottleneck a query (profiler shows DB/ORM time dominant)? | Read `jpa-query-patterns.md` | N+1 and missing indexes dominate typical service latency; JVM tuning is irrelevant here |
| Is the bottleneck thread-pool exhaustion or blocking I/O under high concurrency? | Read `virtual-threads-concurrency.md` | Virtual threads (or a bigger platform-thread pool) address concurrency limits directly |
| Is startup time over ~5s and it matters (serverless, dev loop)? | `@Lazy` beans, conditional beans, or GraalVM native image | Startup is a distinct measurement from steady-state throughput |
| Connection pool sized how? | `(core count × 2) + disk spindles`, monitored, not guessed | Reflects I/O wait ratio; both under- and oversizing cause production incidents |

## Workflow

1. **Understand the problem.** State a concrete target and current measurement: "Order creation P99 <100ms; currently 250ms, measured via load test." Vague reports ("it's slow") aren't actionable.
2. **Profile the current state.** Capture a JFR recording (`-XX:StartFlightRecording=filename=recording.jfr,duration=60s`) or an async-profiler flamegraph under representative load. Pull GC logs (`-Xlog:gc*`) alongside it.
3. **Identify the bottleneck.** Read the flamegraph: a wide block in database I/O means query work; a wide block in a `synchronized` method means contention (and, on virtual threads, pinning); GC pause spikes mean heap/GC tuning; high CPU with low throughput usually means an inefficient algorithm, not infrastructure.
4. **Apply one targeted fix.** Change exactly one thing per iteration — a query rewrite, a cache, a pool size, a GC flag — so the next benchmark attributes the delta correctly.
5. **Benchmark the improvement.** JMH for micro-optimizations (guards against JIT dead-code elimination); a load test (`wrk`, Gatling) for macroscopic changes, comparing RPS and P99 before/after on the same workload.
6. **Document the optimization.** Record the bottleneck, the fix, the before/after numbers, and the trade-off accepted (e.g., a larger result set for fewer round trips) — for a significant or hard-to-reverse architectural trade-off (e.g., a GraalVM migration, a reactive rewrite), use this repo's `write-adr` skill instead of an inline comment.

## Patterns

### Capturing a JFR profile and a flamegraph

```bash
java -XX:StartFlightRecording=filename=recording.jfr,duration=60s \
     -XX:FlightRecorderOptions=stackdepth=64 \
     -jar application.jar

# async-profiler for a sharper flamegraph
async-profiler record -d 30 -f flamegraph.html -e cpu $(pgrep -f application.jar)
# Open flamegraph.html; the widest blocks are the hotspots worth chasing.
```

### N+1 elimination (the highest-leverage fix in most services)

```java
// BEFORE: 1 query for orders + N queries for each order's customer
public List<Order> getOrders() {
    List<Order> orders = orderRepository.findAll();
    for (Order order : orders) {
        order.setCustomer(customerRepository.findById(order.getCustomerId()).orElse(null));
    }
    return orders;
}

// AFTER: one query via JOIN FETCH / EntityGraph — see jpa-query-patterns.md
public List<OrderWithCustomerDto> getOrders() {
    return orderRepository.findAllWithCustomer();
}
```

### JMH microbenchmark to validate a change

```java
@State(Scope.Benchmark)
public class OrderQueryBenchmark {
    @Benchmark
    public List<OrderWithCustomerDto> benchmarkGetOrders(OrderServiceState state) {
        return state.service.getOrders();
    }
}
// gradle jmh — compare throughput/ops before and after the query change.
```

### HikariCP sizing and health monitoring

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 18       # (8 cores * 2) + 2 disk spindles
      minimum-idle: 10            # keep warm; avoids per-request creation cost
      connection-timeout: 10000   # fail fast rather than queue indefinitely
      idle-timeout: 600000
      max-lifetime: 1800000       # recycle before the DB or LB drops it
```

```java
@GetMapping("/actuator/health/db")
public PoolStats poolStats(DataSource dataSource) {
    HikariPoolMXBean pool = ((HikariDataSource) dataSource).getHikariPoolMXBean();
    return new PoolStats(pool.getActiveConnections(), pool.getIdleConnections(),
        ((HikariDataSource) dataSource).getMaximumPoolSize());
}
// Alert when active connections approach 80% of max — that's saturation, not a spike.
```

### Startup optimization: lazy beans and conditional loading

```java
@Configuration
public class DataSourceConfig {
    @Bean
    @Lazy
    public DataSource dataSource() {
        return HikariDataSourceBuilder.create().build();   // built on first injection, not at boot
    }
}

@Configuration
@ConditionalOnProperty(name = "feature.batch.enabled", havingValue = "true")
public class BatchConfig { /* only loaded when the feature is on */ }
```

GraalVM native image compilation (`gradle nativeCompile`) cuts a ~3s JVM startup to roughly ~100ms, at the cost of reflection hints and no dynamic class loading — reach for it only when cold-start time is itself the SLA (serverless, CLI tools), not as a default.

### Detecting virtual-thread pinning (see `virtual-threads-concurrency.md` for the fix)

```bash
java -Djdk.tracePinnedThreads=short -Dspring.threads.virtual.enabled=true -jar application.jar
# Output points at the exact synchronized block pinning the carrier thread.
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Optimization "improved" a benchmark but production didn't change | Optimized a non-bottleneck; never profiled first | Always profile before choosing what to fix; re-verify the bottleneck after each change |
| GC tuning yields ~0% improvement | 80% of time is in database queries, not GC | Fix the query/algorithm first — JVM tuning cannot fix an algorithmic problem |
| Throughput collapses under concurrent load despite virtual threads enabled | `synchronized` block pins the carrier thread | Replace with `ReentrantLock`/`@Cacheable`; see `virtual-threads-concurrency.md` |
| Connection-timeout errors under moderate load | Pool undersized for the I/O wait ratio | Apply the sizing formula; monitor active-connection percentage, don't guess |
| Full GC events recurring | Heap too small, or a real memory leak masquerading as GC pressure | Heap dump analysis first; increase heap only after ruling out a leak |
| Native image migration stalls indefinitely | Reflection-based code (some Jackson/AOP usage) has no reflection hints | Budget explicit time for reflect-config generation; don't treat it as a drop-in flag |
| "It's faster" with no numbers to show for it | Benchmark improvement not documented | Record before/after metrics and the trade-off accepted, every time |
| Micro-optimization shipped despite profiler showing it's <1% of runtime | Chased CPU micro-tuning before ruling out algorithm/architecture levels | Work top-down through the hierarchy; verify with the profiler before committing effort |

## Quality Checklist

- [ ] Baseline latency/throughput/GC measured before any change
- [ ] A JFR profile or flamegraph confirms the actual bottleneck, not an assumption
- [ ] Exactly one optimization applied per iteration, benchmarked immediately after
- [ ] Improvement is >10% or the change isn't worth the risk/complexity introduced
- [ ] GC logs reviewed for unexpected Full GC or pause spikes after any heap/GC change
- [ ] Connection pool sized by formula and monitored, not left at a framework default under real load
- [ ] Virtual threads considered only for I/O-bound workloads with synchronized code already eliminated
- [ ] Heap dump reviewed if memory pressure is suspected — ruled out a leak before tuning GC
- [ ] Load test (not just a unit benchmark) confirms the improvement at production-representative scale
- [ ] Optimization documented: bottleneck, fix, before/after numbers, and the trade-off accepted
