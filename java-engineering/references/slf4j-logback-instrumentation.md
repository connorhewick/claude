# SLF4J & Logback Instrumentation

Structured, correlated, production-safe logging for Spring Boot services — SLF4J's fluent API, MDC-based request correlation, and JSON output for aggregation.

---

## Overview

SLF4J plus Logback is the standard logging stack for Spring Boot: SLF4J is the facade every library and application code logs through, Logback is the implementation that dispatches those events to appenders. The philosophy here is that logs are a production interface, not a debugging afterthought — every log statement should be structured (key-value, not concatenated strings), correlated (a request ID or trace ID ties related lines together across services), and safe (no secrets, no PII, no attacker-controlled logger names). `System.out.println`/`printStackTrace` bypass all of this and have no place in production code.

## Core Concepts

**MDC bridges request scope to logging without threading context through every method signature.** The Mapped Diagnostic Context is a thread-local map; anything put into it (a request ID, a user ID) is automatically appended to every log line emitted on that thread until it's cleared. This is what lets a service-layer log statement three calls deep still carry the request ID without passing it as a parameter everywhere.

**The logging pipeline is parser → appenders → encoders → output, and Spring profiles branch it for dev vs. prod.** Logback reads `logback-spring.xml`, and Spring's `<springProfile>` blocks let a dev profile use a human-readable `PatternLayoutEncoder` on console while a prod profile switches to a JSON encoder for an aggregator (Logstash/ELK, or any JSON-log-ingesting platform) — same code, different output shape, chosen at deploy time.

**The fluent API is the structured-logging default, not string concatenation.** SLF4J 2.x's `log.atInfo().addKeyValue("orderId", id).log("...")` evaluates lazily (no cost if the level is disabled) and emits key-value pairs the aggregator can parse directly, instead of a human-readable sentence a machine has to regex apart. Placeholder-style calls (`log.debug("Fetching {}", id)`) are an acceptable, lighter-weight alternative for routine DEBUG-level flow where structured fields add little value; string concatenation is never acceptable at any level.

**Logging is scoped by layer, and each layer has a different job.** Controllers log request/response boundaries at INFO — MDC already carries the correlation ID, so there's nothing else to add. Services log business events and state transitions at INFO, routine flow at DEBUG, and recoverable failures at WARN. Repositories log query intent at DEBUG only — exceptions are the service layer's job to log once, not the repository's job to log and rethrow (double-logging the same failure at two layers wastes log volume and confuses on-call).

**Virtual threads break MDC's thread-local assumption.** A virtual thread handed off to a new carrier thread (or a task submitted to an executor) does not inherit the parent's MDC automatically — the child sees an empty context. A `TaskDecorator` that captures `MDC.getCopyOfContextMap()` at submit time and reapplies it inside the child task (clearing it in `finally`) is required wherever async work needs correlated logs; see `virtual-threads-concurrency.md` for the same pattern in the context of `ScopedValue` as a MDC alternative.

**Never let external input become a logger name, an MDC key, or the log message body itself.** A user-controlled string used as a `LoggerFactory.getLogger(name)` argument or an MDC key lets an attacker inject arbitrary logger namespaces or pollute the diagnostic context. Fixed logger names (`LoggerFactory.getLogger(OrderService.class)`) and fixed MDC keys with sanitized values are the only safe pattern. The same discipline applies to log content generally: never log full request/response bodies, passwords, tokens, or other sensitive fields — log identifiers and metadata (content type, length, ID) instead, and let a downstream system with proper access controls hold the sensitive payload if it must be retained at all.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Dev environment logging? | `ConsoleAppender` + `PatternLayoutEncoder`, app packages at DEBUG | Human-readable during local development |
| Prod environment logging? | JSON encoder (e.g. `LogstashEncoder`) on stdout or rolling file | Machine-parseable by the log aggregator; framework loggers capped at WARN to cut noise |
| Need to correlate logs across services? | Propagate/generate a correlation ID in a request filter, put it in MDC | One ID ties every service's logs for one logical request together |
| Distributed tracing already in place? | Inject `traceId`/`spanId` into MDC from the active span | Aggregators auto-parse these fields for trace-log correlation |
| Async work (executor, scheduler, virtual threads) needs correlated logs? | `TaskDecorator` capturing/restoring MDC | MDC is thread-local; it does not propagate to a new thread on its own |
| Log volume from a loop? | One summary log before/after the loop, not one per item | Per-item logging in a tight loop overwhelms the aggregator and adds real latency |
| Need machine-parseable structured fields? | SLF4J fluent API (`atInfo().addKeyValue(...)`) | Lazy evaluation, structured output; string concatenation always evaluates and can't be parsed reliably |
| Need a metric derived from log volume (e.g. error rate)? | A custom `Appender` incrementing a Micrometer counter, tagged by level/logger | Gets an error-rate metric without a separate instrumentation pass |

## Workflow

1. **Configure `logback-spring.xml` first** — dev/prod profiles, JSON encoding for prod, framework loggers capped. This is foundational; instrument code against a config that already exists.
2. **Add a request-entry filter** (`OncePerRequestFilter`) that generates/reads a correlation ID and puts it, along with method/path, into MDC — clearing it in `finally`, unconditionally.
3. **Instrument service-layer code** with `@Slf4j`: INFO for business events and state transitions, DEBUG for routine flow, WARN for recoverable failures inside `orElseThrow`-style not-found paths.
4. **Instrument repository-layer code** at DEBUG only — query intent, not exceptions (the service layer owns exception logging).
5. **Wire MDC propagation for async/virtual-thread work** via a `TaskDecorator` on every executor and scheduler bean that runs work off the request thread.
6. **Add tracing correlation** if distributed tracing is present — inject `traceId`/`spanId` into MDC from the active span.
7. **Verify**: confirm JSON output in the prod profile, confirm correlation ID appears on every log line for one request, confirm MDC is empty at the start of each new request (no leakage from a pooled thread).

## Patterns

### `logback-spring.xml`: profile-switched dev console vs. prod JSON

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="ch.qos.logback.classic.encoder.PatternLayoutEncoder">
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO"><appender-ref ref="CONSOLE"/></root>
        <logger name="com.example.ordersystem" level="DEBUG"/>
    </springProfile>

    <springProfile name="prod">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeContext>true</includeContext>
                <includeMdcData>true</includeMdcData>
                <fieldNames>
                    <timestamp>@timestamp</timestamp>
                    <level>severity</level>
                    <message>msg</message>
                </fieldNames>
            </encoder>
        </appender>
        <root level="INFO"><appender-ref ref="JSON"/></root>
        <logger name="org.springframework" level="WARN"/>
        <logger name="org.hibernate" level="WARN"/>
    </springProfile>

    <statusListener class="ch.qos.logback.core.status.NopStatusListener"/>
</configuration>
```

Requires `net.logstash.logback:logstash-logback-encoder` on the classpath alongside `spring-boot-starter-logging`.

### Request-entry MDC filter

```java
@Component
public class RequestIdFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                     FilterChain filterChain) throws ServletException, IOException {
        String requestId = UUID.randomUUID().toString();
        String correlationId = Optional.ofNullable(request.getHeader("correlationId")).orElse(requestId);

        MDC.put("requestId", requestId);
        MDC.put("correlationId", correlationId);
        MDC.put("method", request.getMethod());
        MDC.put("path", request.getRequestURI());
        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();   // non-negotiable — pooled threads otherwise leak context into the next request
        }
    }
}
```

### Fluent API at service boundaries

```java
@Slf4j
@Service
public class OrderService {
    public OrderResponse createOrder(CreateOrderRequest request) {
        log.atInfo()
            .addKeyValue("customerId", request.getCustomerId())
            .addKeyValue("itemCount", request.getItems().size())
            .log("Order creation initiated");

        Order saved = repository.save(toEntity(request));

        log.atInfo().addKeyValue("orderId", saved.getId()).log("Order created");
        return new OrderResponse(saved.getId(), saved.getStatus());
    }

    public OrderResponse getOrder(Long orderId) {
        log.atDebug().addKeyValue("orderId", orderId).log("Fetching order");
        return repository.findById(orderId)
            .map(o -> new OrderResponse(o.getId(), o.getStatus()))
            .orElseThrow(() -> {
                log.atWarn().addKeyValue("orderId", orderId).log("Order not found");
                return new OrderNotFoundException("Order " + orderId + " not found");
            });
    }
}
```

### Log injection prevention

```java
// DANGEROUS: attacker-controlled logger name / MDC key
Logger logger = LoggerFactory.getLogger(request.getParameter("logger"));
MDC.put(request.getParameter("mdcKey"), value);

// SAFE: fixed logger, fixed MDC keys, sanitized values
private static final Logger log = LoggerFactory.getLogger(OrderService.class);
MDC.put("customerId", sanitizeId(request.getParameter("customerId")));
```

### MDC propagation across virtual threads (see `virtual-threads-concurrency.md` for `ScopedValue` as an alternative)

```java
@Bean
public TaskDecorator mdcTaskDecorator() {
    return task -> {
        Map<String, String> mdcMap = MDC.getCopyOfContextMap();
        return () -> {
            if (mdcMap != null) MDC.setContextMap(mdcMap);
            try {
                task.run();
            } finally {
                MDC.clear();
            }
        };
    };
}

@Bean
public AsyncTaskExecutor asyncExecutor(TaskDecorator decorator) {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setVirtualThreads(true);
    executor.setTaskDecorator(decorator);
    executor.initialize();
    return executor;
}
```

### Rolling JSON file appender and a metrics-from-logs appender

```xml
<appender name="JSON_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>logs/app.json</file>
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <includeMdcData>true</includeMdcData>
        <customFields>{"service":"order-system","environment":"prod"}</customFields>
    </encoder>
    <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
        <fileNamePattern>logs/app-%d{yyyy-MM-dd}-%i.json</fileNamePattern>
        <maxFileSize>100MB</maxFileSize>
        <maxHistory>30</maxHistory>
    </rollingPolicy>
</appender>
```

```java
public class MetricsAppender extends AppenderBase<ILoggingEvent> {
    private final MeterRegistry meterRegistry;
    @Override
    protected void append(ILoggingEvent event) {
        Counter.builder("logs")
            .tag("level", event.getLevel().toString())
            .tag("logger", event.getLoggerName())
            .register(meterRegistry)
            .increment();
    }
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Log message costs CPU even when the level is disabled | String concatenation (`"x " + var`) instead of placeholders/fluent API | `log.atInfo().addKeyValue(...).log(...)` or `{}` placeholders — both defer evaluation |
| Logs spike and the aggregator falls behind during a batch job | Logging inside a tight loop, once per item | Log a summary before/after the loop; log per-item only at DEBUG if genuinely needed |
| Prod logs leak passwords/tokens/full payloads | Logging full request/response bodies "for debugging" | Log identifiers and metadata (content-type, length, ID) — never the payload itself |
| Next request's logs contain the previous request's user ID | `MDC.clear()` missing or not in a `finally` block | Always clear MDC in `finally` — pooled threads reuse the same thread-local map |
| Async/virtual-thread logs have no request ID | MDC is thread-local; it doesn't propagate to a new thread automatically | `TaskDecorator` capturing/restoring MDC on every executor and scheduler |
| Attacker can create arbitrary logger namespaces or pollute MDC | User input used as a logger name or MDC key | Fixed logger names, fixed MDC keys, sanitized values only |
| Same exception appears twice in the logs | Repository logs and rethrows; service logs again | Log the failure once, at the layer that decides what to do about it (usually the service) |
| `System.out.println` calls found in production code | Bypassing SLF4J entirely | Replace with the appropriate `log.*` call; `System.out` has no MDC context and corrupts JSON log streams |

## Quality Checklist

- [ ] `logback-spring.xml` configured with a JSON encoder for the prod profile
- [ ] A request filter (or equivalent) injects request/correlation ID into MDC on every request
- [ ] `MDC.clear()` runs in a `finally` block or servlet filter — no leakage across pooled threads
- [ ] No `System.out.println`/`printStackTrace` in production code
- [ ] No string concatenation in log calls — fluent API or placeholders only
- [ ] `TaskDecorator` configured on every async executor/scheduler for MDC propagation
- [ ] Prod log level is INFO by default; DEBUG only for specifically targeted loggers during investigation
- [ ] No PII, secrets, tokens, or full request/response bodies appear in any log statement
- [ ] Trace/span IDs injected into MDC if distributed tracing is present
- [ ] Logger names and MDC keys are fixed constants — never derived from user input
- [ ] Each failure is logged exactly once, at the layer that decides how to handle it
