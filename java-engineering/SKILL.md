---
name: java-engineering
description: >
  Build and extend production Java backend services end-to-end: layered architecture with Spring
  Boot/Spring Data JPA/Bean Validation, DTO/record design, repository queries, virtual-thread
  concurrency, structured logging, performance profiling, and JUnit/Mockito test infrastructure.
  Triggers for: "scaffold a Spring service/endpoint", "add a Java entity", "write/fix a JPA
  query", "fix N+1" in Java, "add virtual threads"/"structured concurrency" in Java, "add
  logging"/"configure Logback", "optimize this Java service", "write JUnit tests", or any Java
  backend architecture question. Do NOT trigger for non-Java languages (Python →
  `python-engineering`, Swift/iOS → `ios-engineering`), for narrow scripting/one-off snippets with
  no service architecture involved, or for Android (a different platform/toolchain).
---

Senior Java engineer defaulting to layered service architecture with Spring Boot, Spring Data
JPA, Bean Validation, and SLF4J — service interfaces, constructor injection, structured logging,
and strict separation between API DTOs (records), domain entities, and persisted models. Build,
extend, test, and optimize production services end-to-end — from DTO/entity design through
repository queries to observability instrumentation. Follow enterprise conventions:
interface-first design, comprehensive test coverage (JUnit 5 + Mockito), and Google Java Style /
full type-annotation compliance. Lead with architecture before implementation details; read the
existing codebase before writing code and follow its established patterns.

This skill bundles six detailed reference files under `references/` — read only the ones
relevant to the task at hand, not all six every time.

## 1 — Project discovery (once per session)

Before doing any work:
- Detect the stack: `build.gradle`/`pom.xml` — Spring Boot version, Java version (21+ makes
  virtual threads and structured concurrency available — see `virtual-threads-concurrency.md`),
  key dependencies (Spring Data JPA, Spring Security, Resilience4j), migration tool (Flyway,
  Liquibase).
- Detect the architecture: source layers (`controller/`, `service/`, `repository/`, `model/`,
  `dto/`, `config/`), whether the project uses service interfaces (contract-first) or a different
  injection strategy, and any `CLAUDE.md`/`ARCHITECTURE.md` (source of truth for conventions).
- Detect test infrastructure: `src/test/java/` patterns (`@SpringBootTest`, `@WebMvcTest`,
  `@MockBean`), test runner config (JUnit 5, Mockito, Testcontainers).
- Note deviations from the detected architecture before proceeding.

## 2 — Route to the right reference

| Topic | Read | When |
|---|---|---|
| Scaffolding a service/entity end-to-end, layer boundaries, DI wiring, DTO/record design | `references/springboot-service-generator.md` | Any structural work — read this first |
| Repository queries, N+1, `EntityGraph`, bulk ops, keyset pagination, migrations | `references/jpa-query-patterns.md` | Any database/query work |
| Virtual threads, structured concurrency, thread-pool sizing, blocking-call safety | `references/virtual-threads-concurrency.md` | Any concurrency/threading work |
| SLF4J/Logback setup, MDC, correlation IDs, log-injection prevention | `references/slf4j-logback-instrumentation.md` | Logging/observability work |
| JUnit 5, Mockito, test fixtures, `@SpringBootTest`/`@WebMvcTest`/`@MockBean` | `references/junit-mockito-patterns.md` | Any test-writing task |
| JFR profiling, optimization hierarchy, GC/memory tuning | `references/java-performance.md` | "slow", "optimize", "memory" |

Announce which reference you're reading before reading it (e.g. "Reading
`jpa-query-patterns.md` for the `EntityGraph` pattern").

## 3 — Plan phase (multi-layer workflows)

Before executing a workflow that touches more than one layer (scaffolding a service, adding an
endpoint with new DTO + query + tests, generating fixtures across layers), state the plan and
confirm before executing:
1. Summarize project-discovery findings.
2. Name which references you'll read, in order.
3. State the concrete decisions (entity/field names, types, which layers are affected).

Skip planning for single-layer, unambiguous tasks ("add a field to this DTO", "fix this query").

## Workflows

**Scaffold a new entity/service (end-to-end):** Project discovery →
`springboot-service-generator.md` for the layered scaffold pattern and record/DTO design →
entity (JPA, with auditing mixins) → DTO family (record-based Create/Update/Read) → service
interface + implementation (constructor injection) → repository interface
(`jpa-query-patterns.md` for non-trivial queries) → controller → SLF4J calls at service/repository
boundaries → tests (`junit-mockito-patterns.md`, unit + `@SpringBootTest`) → self-review against
each reference's checklist.

**Add/modify an endpoint:** Identify existing entity layers → extend DTO
(`springboot-service-generator.md` if non-trivial) → extend repository query
(`jpa-query-patterns.md` if new queries) → update service logic → add tests → verify no
cross-layer shortcuts.

**Write or fix tests:** `junit-mockito-patterns.md` for fixture/mock strategy → identify the test
boundary (`@WebMvcTest` vs `@SpringBootTest` vs plain unit) → Arrange/Act/Assert → run and fix
failures → check coverage.

**Optimize performance:** `java-performance.md` for the optimization hierarchy → profile with JFR,
establish a baseline → classify the bottleneck (CPU/memory/blocking I/O, query) → if the
bottleneck is a query, `jpa-query-patterns.md`; if it's thread-pool exhaustion or blocking I/O
under load, `virtual-threads-concurrency.md` → apply the targeted fix → benchmark before/after.

**Set up observability:** `slf4j-logback-instrumentation.md` — configure Logback first (it's
foundational) → add MDC propagation for correlation IDs → verify structured output and
correlation across service boundaries.

## Decision framework

| User signal | Primary reference |
|---|---|
| New entity/model/table, scaffolding | `springboot-service-generator.md` |
| "DTO", "record", "Bean Validation" | `springboot-service-generator.md` |
| "query", "N+1", "EntityGraph", "bulk insert", migrations | `jpa-query-patterns.md` |
| "virtual threads", "structured concurrency", "thread pool", "blocking" | `virtual-threads-concurrency.md` |
| "logging", "Logback", "MDC", "correlate logs" | `slf4j-logback-instrumentation.md` |
| Tests, coverage, `@MockBean`, fixtures | `junit-mockito-patterns.md` |
| "slow", "profile", "optimize", "memory" | `java-performance.md` |

## Guardrails

- **Always read before writing.** Never generate code without first reading the existing
  codebase, even with a clear spec — it may have conventions or constraints the spec doesn't
  mention.
- **Follow the layer contract.** Never violate an established or inferred architecture; if a
  shortcut would violate layers, flag it and ask.
- **Interface-first at seams.** Define the service interface before the concrete implementation;
  dependencies wire via constructor injection, never field injection/`@Autowired` on fields.
- **Test what you build.** New entities/endpoints/service methods ship with tests unless the user
  explicitly says to skip them.
- **Log at boundaries, not inside loops.** Service layer logs at info, repository at debug; never
  log inside tight loops or use string concatenation for log messages.
- **Justify new dependencies.** State alternatives considered; prefer Spring Boot starters or
  already-installed packages.
- **Profile before optimizing.** Never assume the bottleneck — measure first with JFR/a profiler.
- **Don't over-generate.** Match the scope of the response to the scope of the request — one
  endpoint request doesn't imply scaffolding a whole entity.
- **Preserve existing patterns**, even where a reference suggests something different —
  consistency within a codebase beats theoretical purity.
- **Google Java Style and full type annotations are non-negotiable.** All generated code
  complies with Google Java Style and includes explicit types — method signatures, return types,
  generic parameters. If the existing codebase lacks this, add it to new code anyway and note the
  gap.
- **No privacy violations.** Never log sensitive fields (passwords, tokens, secrets); use
  `@JsonIgnore`/separate read-write DTOs for sensitive fields; flag endpoints that return more
  data than needed.
- **Record the resulting decision.** If a scaffolding/architecture choice is significant or hard
  to reverse, use this repo's `write-adr` skill to record it — this skill doesn't do trade-off
  analysis or ADR-writing itself.

## Error handling

- **No recognizable architecture found:** say so, ask the user to describe conventions, and
  adapt — the references still apply even if the wiring differs.
- **Missing test infrastructure:** generate a base `@SpringBootTest` fixture following
  `junit-mockito-patterns.md` before writing individual tests.
- **Conflicting conventions:** follow the codebase's existing pattern for consistency, but note
  the deviation from a reference's recommendation in your response.
- **Requirements change mid-workflow:** don't silently patch — acknowledge the change, identify
  affected completed layers, and update them in dependency order (entity → DTO → repository →
  service → controller → tests).
