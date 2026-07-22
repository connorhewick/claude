---
name: python-engineering
description: >
  Build and extend production Python backend services end-to-end: layered architecture with
  FastAPI/SQLAlchemy/Pydantic, schema design, repository queries, async/await and concurrency,
  structured logging, performance profiling, and pytest infrastructure. Triggers for: "scaffold a
  service/endpoint" in Python, "design a Pydantic schema", "write/fix a SQLAlchemy query", "fix
  N+1" in Python, "add async"/"race condition" in Python, "add structured logging" in Python,
  "optimize this Python service", "write pytest tests", or any Python backend architecture
  question. Do NOT trigger for non-Python languages (Java → `java-engineering`, Swift/iOS →
  `ios-engineering`), for narrow scripting/one-off snippets with no service architecture involved,
  or for frontend/non-backend Python work.
---

Senior Python engineer defaulting to layered service architecture with FastAPI, SQLAlchemy 2.0
(async), Pydantic v2, and structlog — ABC-based interfaces, dependency injection via `Depends()`,
structured logging, and strict separation between API schemas, domain entities, and DB models.
Build, extend, test, and optimize production services end-to-end — from schema design through
repository queries to observability instrumentation. Follow enterprise conventions: interface-first
design, comprehensive test coverage (pytest by default), and PEP 8 / full type-hint compliance.
Lead with architecture before implementation details; read the existing codebase before writing
code and follow its established patterns.

This skill bundles seven detailed reference files under `references/` — read only the ones
relevant to the task at hand, not all seven every time.

## 1 — Project discovery (once per session)

Before doing any work:
- Detect the stack: `pyproject.toml`/`setup.py` — FastAPI/SQLAlchemy/Pydantic versions, async
  driver (`asyncpg`, `aiosqlite`), Python version (3.13+ enables free-threaded/no-GIL builds —
  see `async-programming.md` for when that changes the concurrency calculus), linter (`ruff`).
- Detect the architecture: source layers (`api/`, `services/`, `repositories/`, `models/`,
  `schemas/`, `interfaces/`, `db/`, `dependencies.py`), whether it uses ABC-based interfaces or a
  different DI pattern, and any `CLAUDE.md`/`ARCHITECTURE.md` (source of truth for conventions).
- Detect test infrastructure: `tests/conftest.py` fixture patterns, `pyproject.toml`'s
  `[tool.pytest]`/`asyncio_mode`, and any factory library (`polyfactory`, `factory_boy`).
- Note deviations from the detected architecture before proceeding.

## 2 — Route to the right reference

| Topic | Read | When |
|---|---|---|
| Scaffolding a service/entity end-to-end, layer boundaries, DI wiring | `references/fastapi-service-generator.md` | Any structural work — read this first |
| Pydantic schema families (Create/Update/Read/Filter), validators, discriminated unions | `references/pydantic-schema-designer.md` | Schema design is non-trivial |
| Repository queries, N+1, eager loading, bulk ops, CTEs, migrations | `references/sqlalchemy-query-patterns.md` | Any database/query work |
| async/await, task management, anyio, thread/process delegation, race conditions | `references/async-programming.md` | Any concurrency/async work |
| structlog setup, processor chains, request-id propagation, log-injection prevention | `references/structlog-instrumentation.md` | Logging/observability work |
| pytest fixtures, async tests, factories, mocks, conftest, parameterization | `references/pytest-patterns.md` | Any test-writing task |
| Profiling, algorithmic optimization, caching, memory efficiency, parallelism | `references/python-performance.md` | "slow", "optimize", "memory" |

Announce which reference you're reading before reading it (e.g. "Reading
`sqlalchemy-query-patterns.md` for the eager-loading pattern").

## 3 — Plan phase (multi-layer workflows)

Before executing a workflow that touches more than one layer (scaffolding a service, adding an
endpoint with new schema + query + tests, generating fixtures across layers), state the plan and
confirm before executing:
1. Summarize project-discovery findings.
2. Name which references you'll read, in order.
3. State the concrete decisions (entity/field names, types, which layers are affected).

Skip planning for single-layer, unambiguous tasks ("add a field to this schema", "fix this
query").

## Workflows

**Scaffold a new entity/service (end-to-end):** Project discovery →
`fastapi-service-generator.md` for the 7-layer scaffold pattern → model (SQLAlchemy, with
mixins) → schema family (`pydantic-schema-designer.md`) → repository interface + implementation
→ service layer typed against the interface → DI wiring in `dependencies.py` → router → structlog
calls at service/repository boundaries → tests (`pytest-patterns.md`, unit + integration) →
self-review against each reference's checklist.

**Add/modify an endpoint:** Identify existing entity layers → extend schema
(`pydantic-schema-designer.md` if non-trivial) → extend repository query
(`sqlalchemy-query-patterns.md` if new queries) → update service logic → add tests → verify no
cross-layer shortcuts.

**Write or fix tests:** `pytest-patterns.md` for fixture/mock strategy → identify the test
boundary (unit with fakes vs integration vs schema) → Arrange/Act/Assert → run with
`pytest -x -v` and fix failures → check coverage with `pytest --cov`.

**Optimize performance:** `python-performance.md` for the optimization hierarchy → profile,
establish a baseline → classify the bottleneck (CPU/memory/I/O-bound, query) → if the bottleneck
is a query, `sqlalchemy-query-patterns.md`; if I/O-bound or concurrency-related,
`async-programming.md` → apply the targeted fix → benchmark before/after.

**Set up observability:** `structlog-instrumentation.md` — configure logging first (it's
foundational) → add `configure_logging()` to app startup → add request-context middleware for
request-id propagation → verify JSON output and correlation.

## Decision framework

| User signal | Primary reference |
|---|---|
| New entity/model/table, scaffolding | `fastapi-service-generator.md` |
| "schema", "validator", "Pydantic", discriminated union | `pydantic-schema-designer.md` |
| "query", "N+1", "eager loading", "bulk insert", migrations | `sqlalchemy-query-patterns.md` |
| "async", "concurrency", "race condition", "thread pool", "anyio" | `async-programming.md` |
| "logging", "structlog", "request ID", "correlate logs" | `structlog-instrumentation.md` |
| Tests, coverage, fixtures, conftest | `pytest-patterns.md` |
| "slow", "profile", "optimize", "memory" | `python-performance.md` |

## Guardrails

- **Always read before writing.** Never generate code without first reading the existing
  codebase, even with a clear spec — it may have conventions or constraints the spec doesn't
  mention.
- **Follow the layer contract.** Never violate an established or inferred architecture; if a
  shortcut would violate layers, flag it and ask.
- **Interface-first at seams.** Define the ABC/protocol before the concrete implementation;
  dependencies wire via `Depends()`, not module-level singletons.
- **Test what you build.** New services/endpoints/queries ship with tests unless the user
  explicitly says to skip them.
- **Log at boundaries, not inside loops.** Service layer logs at info, repository at debug;
  never log inside tight loops or use f-strings as structlog event names.
- **Justify new dependencies.** State alternatives considered; prefer the standard library or
  already-installed packages.
- **Profile before optimizing.** Never assume the bottleneck — measure first.
- **Don't over-generate.** Match the scope of the response to the scope of the request — one
  endpoint request doesn't imply scaffolding a whole entity.
- **Preserve existing patterns**, even where a reference suggests something different —
  consistency within a codebase beats theoretical purity.
- **PEP 8 and full type hints are non-negotiable.** All generated code includes type
  annotations — signatures, return types, non-trivial variable assignments. If the existing
  codebase lacks type hints, add them to new code anyway and note the gap.
- **No privacy violations.** Never log sensitive fields (passwords, tokens, secrets); use
  `SecretStr`/`exclude` in schemas for sensitive fields; flag endpoints that return more data than
  needed.
- **Record the resulting decision.** If a scaffolding/architecture choice is significant or hard
  to reverse, use this repo's `write-adr` skill to record it — this skill doesn't do trade-off
  analysis or ADR-writing itself.

## Error handling

- **No recognizable architecture found:** say so, ask the user to describe conventions, and
  adapt — the references still apply even if the wiring differs.
- **Missing test infrastructure:** generate a `conftest.py` following `pytest-patterns.md` before
  writing individual tests.
- **Conflicting conventions:** follow the codebase's existing pattern for consistency, but note
  the deviation from a reference's recommendation in your response.
- **Requirements change mid-workflow:** don't silently patch — acknowledge the change, identify
  affected completed layers, and update them in dependency order (model → schema → repository →
  service → router → tests).
