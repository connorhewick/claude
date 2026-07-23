# Python Implementation Notes

This appendix translates a finished TDD's API Contract and Data Model sections into concrete
FastAPI/SQLAlchemy signatures — **signatures only, no implementations.** Router functions end
with `...`; every method body is a stub, not working code. Mirror the TDD, don't extend it — if
this appendix would need content the TDD itself doesn't have, that's a gap in the TDD's own
sections 3–4, not something to invent here.

Read this whole file when Project Discovery detects Python/FastAPI as the target stack — it's
short enough not to need staged loading.

## FastAPI layer

- **Router signatures**, one per API Contract endpoint, using the project's actual DI pattern
  (usually `Depends()`), the endpoint's real path/method/status code, and `response_model` set to
  the matching Pydantic schema:

  ```python
  @router.post("/orders", response_model=OrderRead, status_code=201)
  async def create_order(
      payload: OrderCreate,
      current_user: User = Depends(get_current_user),
      repo: IOrderRepository = Depends(get_order_repository),
  ) -> OrderRead: ...
  ```

- **Pydantic schema family** per resource — `Base` (shared fields), `Create`, `Update` (all
  fields optional), `Read` (includes server-generated fields), `Filter` (query-param schema for
  list endpoints). Use a generic `PaginatedResponse[T]` for any list endpoint rather than a
  bespoke wrapper per resource.
- **Error mapping table** — one row per error scenario the TDD's API Contract names:

  | TDD scenario | HTTP status | Exception pattern |
  |---|---|---|
  | Resource not found | 404 | `raise HTTPException(404, detail=...)` |
  | Validation failure | 422 | (handled automatically by Pydantic) |
  | Conflict / duplicate | 409 | `raise HTTPException(409, detail=...)` |

- **DI wiring** — note any addition needed to the project's dependency-provider module (commonly
  `app/dependencies.py`), not a full rewrite of it.
- **Router registration** — the one-line addition to wherever routers are mounted
  (`app.include_router(...)` or equivalent), including prefix/tags if the project uses them.
- **Observability hook naming** — if the project uses structlog/OpenTelemetry (per
  `python-engineering/references/structlog-instrumentation.md`), name the log events/span names
  this feature would emit, matching the project's existing naming convention rather than
  inventing a new one.

## SQLAlchemy layer

- **Model declarations**, SQLAlchemy 2.x style (`Mapped`/`mapped_column`), reusing whatever mixins
  the project already has (a timestamp mixin, a soft-delete mixin, a UUID-primary-key mixin) —
  **flag it explicitly** if a mixin this feature would want isn't found in the project, rather
  than assuming one exists.
- **Relationships** — one-to-many, many-to-many, and self-referential patterns, whichever the
  Data Model section actually needs; don't include relationship kinds the feature doesn't use.
- **Migration stub** — an Alembic `upgrade()`/`downgrade()` pair per new table/column, with an
  explicit note on ordering when a new table has a foreign key to another new table in the same
  TDD (create the referenced table first).
- **Repository interface** — one method per data-access operation the Service & UI Design section
  names, each with an inline comment tracing it back to the specific API endpoint that calls it.
- **Enum fields** — state explicitly whether an enum is DB-native (`postgresql.ENUM`) or
  VARCHAR-backed with application-level validation; don't leave this ambiguous, since migrating
  between the two later is a real cost.

## When to skip sections

| Skip | When |
|---|---|
| Pydantic schema family | Feature reuses an existing resource's schemas unchanged |
| Migration stub | No new table/column — feature only adds new endpoints over existing data |
| Relationships | Feature's new table(s) have no foreign keys to model |
| Observability hook naming | Project has no structured logging/tracing set up yet |

## Quality checklist

- [ ] Every router signature matches an endpoint in the TDD's API Contract — no invented routes
- [ ] Every Pydantic schema in the family is actually needed by an endpoint (no unused `Filter`
      schema for a resource with no list endpoint, etc.)
- [ ] Migration stub ordering is correct for any new-table-to-new-table foreign keys
- [ ] Enum storage strategy (native vs VARCHAR-backed) is stated explicitly, not implied
- [ ] No method bodies — every signature ends in `...`, nothing is actually implemented
