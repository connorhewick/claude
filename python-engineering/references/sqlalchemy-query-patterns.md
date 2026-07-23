# SQLAlchemy Query Patterns

Write correct, N+1-free SQLAlchemy 2.x queries for a repository layer, using the `select()` API,
explicit relationship-loading strategies, and composable query construction.

---

## Overview

Database queries are usually the dominant source of latency in a web service, and SQLAlchemy's
2.x `select()` API is expressive enough that a query can be technically correct while still being
an operational hazard — a single missing eager-load turns a 50ms list endpoint into a 5-second one
the moment production data grows past a handful of rows. The philosophy: **declare loading
strategy at the query site, not on the model** — a relationship's access pattern varies by
endpoint, so the loading strategy belongs where the query is written, not baked into the model
definition where it would apply to every query indiscriminately. Repositories own queries; they
never make business decisions, and they never leak raw rows past their own boundary.

## Core Concepts

**`select()` is the only API for new code.** The legacy `session.query()` interface still runs but
is maintenance-mode only — building on it in 2026 is choosing a dead end. `select()`, `insert()`,
`update()`, `delete()` from `sqlalchemy` compose with `.where()`, `.options()`, `.order_by()` as a
statement you can build up piece by piece, log, and test independently of execution.

**N+1 comes from relying on lazy loading, not from writing a bad query.** The default
`lazy="select"` fires one query *per accessed relationship, per row* — invisible in a unit test
against one row, catastrophic against a thousand. Never set `lazy="joined"` on the model definition
either — that eagerly loads the relationship on *every* query touching the model, even the ones
that don't need it. Declare the strategy per query with `.options()` instead, so each call site
loads exactly what it needs.

**Choose the loading strategy by cardinality and parent count, not habit.** `joinedload` pulls a
relationship into the same query via `JOIN` — cheap for a single parent row or a small one-to-many,
disastrous as a cartesian explosion for a one-to-many with many children and many parents.
`selectinload` issues a second, bounded `IN` query — the safe default for loading a collection
relationship across many parent rows (list endpoints). `subqueryload` re-runs the parent query as a
subquery — reach for it when the parent query itself has joins/filters/limits that would make
`selectinload`'s `IN` clause unreasonably large.

**Keyset pagination beats OFFSET once endpoints page deep.** `OFFSET n` makes the database scan and
discard `n` rows before returning anything — cost grows linearly with page depth. Keyset
(cursor-based) pagination filters on the last-seen sort key instead, making every page O(the same
constant) regardless of depth. Default to OFFSET only for shallow, first-few-pages UIs; switch to
keyset the moment an endpoint might page beyond a few hundred rows.

**Bulk operations bypass the ORM identity map — say so explicitly.** `update()`/`delete()`
constructed via `select()`-style statements operate directly in SQL and don't automatically sync
already-loaded in-memory objects. Async sessions require `execution_options(synchronize_session=False)`
on bulk statements; if the caller needs in-memory consistency afterward, call
`session.expire_all()` explicitly rather than assuming it happened.

**Repository methods compose query fragments, they don't concatenate strings.** A `_base_query()`
returning the standard filtered `select()` and an `_apply_filters()` chaining conditional
`.where()` calls onto it means `list`, `count`, and `export` all share one definition of "what
counts as active" — defined once, not duplicated per method.

## Decision Framework

| Relationship shape | Recommended strategy | Why |
|---|---|---|
| many-to-one (any cardinality) | `joinedload` | Always exactly one related row — cheap to JOIN |
| one-to-many, small (< ~50 children), single parent | `joinedload` | Small enough that a JOIN's row duplication is negligible |
| one-to-many, any size, many parent rows (list endpoints) | `selectinload` | Bounded `IN` query regardless of parent count — the safe default |
| many-to-many, many parent rows | `selectinload` | Same reasoning as one-to-many at scale |
| Parent query already has joins/filters/limits | `subqueryload` | Avoids an unreasonably large `IN` clause from `selectinload` |
| Multi-level relationship chain | Chain strategies per level (`selectinload(...).joinedload(...)`) | Each level can pick what suits its own cardinality |
| Pagination depth is shallow (first few pages) | OFFSET/LIMIT | Simpler; cost is negligible at shallow depth |
| Pagination can go deep (infinite scroll, exports) | Keyset (cursor) pagination | O(1) per page regardless of depth; OFFSET degrades linearly |
| Need IDs back from a bulk insert | `insert(...).returning(...)` | Plain bulk `insert()` doesn't return ORM instances |
| Bulk update/delete on an async session | Add `execution_options(synchronize_session=False)` | Required for async; call `session.expire_all()` after if consistency is needed |
| Complex multi-step analytical query | CTE (`.cte()`) | More readable than deeply nested subqueries |

## Workflow

1. **Identify the data need** — entities, filters, relationships required by the caller.
2. **Choose the statement type** — `select()`, `insert()`, `update()`, `delete()`.
3. **Declare the loading strategy** using the Decision Framework above — never leave it to the
   model's default `lazy` behavior.
4. **Compose the query** by chaining `.where()`, `.options()`, `.order_by()`, `.limit()` on a base
   statement — factor shared fragments into `_base_query()`/`_apply_filters()` helpers.
5. **Handle pagination** — keyset for anything that can page deep, OFFSET only for shallow lists.
6. **Review for anti-patterns**: N+1 from unaccounted relationship access, detached-instance
   access after session close, string-concatenated filters.
7. **Verify against the Quality Checklist** below before the query ships in a repository method.

## Patterns

### Basic select and conditional filtering

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

async def get_by_id(session: AsyncSession, item_id: UUID) -> Item | None:
    stmt = select(Item).where(Item.id == item_id)
    result = await session.execute(stmt)
    return result.scalar_one_or_none()

async def list_items(
    session: AsyncSession, *, category_id: UUID | None = None, is_active: bool = True,
) -> Sequence[Item]:
    stmt = select(Item).where(Item.is_active == is_active)
    if category_id is not None:
        stmt = stmt.where(Item.category_id == category_id)   # chained .where() = AND
    stmt = stmt.order_by(Item.created_at.desc())
    return (await session.execute(stmt)).scalars().all()
```

### Keyset pagination

```python
async def list_after_cursor(
    session: AsyncSession, *, cursor: datetime | None = None, page_size: int = 20,
) -> Sequence[Item]:
    stmt = select(Item).where(Item.is_active == True)
    if cursor is not None:
        stmt = stmt.where(Item.created_at < cursor)          # filter, not OFFSET
    stmt = stmt.order_by(Item.created_at.desc()).limit(page_size)
    return (await session.execute(stmt)).scalars().all()
```

### Relationship loading strategies

```python
from sqlalchemy.orm import joinedload, selectinload

# joinedload — single parent, small relationship
stmt = select(Order).options(joinedload(Order.items)).where(Order.id == order_id)

# selectinload — list endpoint loading a collection for many parents
stmt = select(Order).options(selectinload(Order.items)).where(Order.user_id == user_id)

# Nested, mixed strategies per level
stmt = (
    select(Order)
    .options(
        selectinload(Order.items).joinedload(OrderItem.product),
        joinedload(Order.user),
    )
    .where(Order.id == order_id)
)
```

### Bulk operations

```python
from sqlalchemy import insert, update

async def bulk_create(session: AsyncSession, items: list[ItemCreate]) -> None:
    stmt = insert(Item).values([item.model_dump() for item in items])
    await session.execute(stmt)     # no ORM instances returned; add .returning() if IDs are needed

async def deactivate_old(session: AsyncSession, cutoff: datetime) -> int:
    stmt = (
        update(Item)
        .where(Item.last_accessed < cutoff)
        .values(is_active=False)
        .execution_options(synchronize_session=False)   # required for async sessions
    )
    result = await session.execute(stmt)
    return result.rowcount

# Upsert (Postgres)
from sqlalchemy.dialects.postgresql import insert as pg_insert

async def upsert_item(session: AsyncSession, data: dict) -> None:
    stmt = pg_insert(Item).values(**data)
    stmt = stmt.on_conflict_do_update(
        index_elements=[Item.external_id],
        set_={"name": stmt.excluded.name, "updated_at": func.now()},
    )
    await session.execute(stmt)
```

### CTE for readable multi-step analytics

```python
from sqlalchemy import cte, func

active_orders = (
    select(Order.user_id, func.count().label("order_count"), func.sum(Order.total).label("total_spent"))
    .where(Order.status == "completed")
    .group_by(Order.user_id)
    .cte("active_orders")
)

stmt = (
    select(User, active_orders.c.order_count, active_orders.c.total_spent)
    .join(active_orders, User.id == active_orders.c.user_id)
    .where(active_orders.c.total_spent > 1000)
)
```

### Repository composition pattern

```python
class ItemRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _base_query(self) -> Select[tuple[Item]]:
        return select(Item).where(Item.is_deleted == False)

    def _apply_filters(self, stmt: Select, filters: ItemFilter) -> Select:
        if filters.category_id is not None:
            stmt = stmt.where(Item.category_id == filters.category_id)
        if filters.search is not None:
            stmt = stmt.where(Item.name.ilike(f"%{filters.search}%"))
        return stmt

    async def list(self, filters: ItemFilter, page: int, size: int) -> Sequence[Item]:
        stmt = self._apply_filters(self._base_query(), filters)
        stmt = stmt.order_by(Item.created_at.desc()).offset((page - 1) * size).limit(size)
        stmt = stmt.options(selectinload(Item.category))
        return (await self._session.execute(stmt)).scalars().all()
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| List endpoint slows drastically as data grows | N+1: relationship accessed in a loop with no eager load | Add `selectinload` (or `joinedload` for small/single-parent cases) to the parent query |
| `DetachedInstanceError` accessing a relationship | Session already closed when the lazy attribute was touched | Eager-load everything needed via `.options()` before the session ends |
| Every query on a model implicitly joins a relationship it doesn't need | `lazy="joined"` set on the model definition | Declare loading strategy per query with `.options()`, never on the model |
| Cartesian explosion — huge, duplicated result rows | `joinedload` used on a large one-to-many across many parents | Switch to `selectinload` for that shape |
| Bulk update silently leaves stale in-memory objects | Missing `synchronize_session=False`, or missing `expire_all()` when consistency is needed | Set the execution option; call `expire_all()` explicitly if callers need fresh state |
| Deep-page list endpoint gets progressively slower | OFFSET pagination scanning and discarding rows | Switch to keyset pagination for endpoints that can page beyond a few hundred rows |
| Filter logic duplicated across `list`/`count`/`export` | No shared query-composition helper | Factor into `_base_query()`/`_apply_filters()` reused by all three |
| New code still calls `session.query(...)` | Habit/copy-paste from legacy code | Use the `select()` API — `session.query()` is maintenance-mode only |

## Quality Checklist

- [ ] Uses the `select()`/`insert()`/`update()`/`delete()` API — no `session.query()` in new code
- [ ] Every accessed relationship has an explicit loading strategy declared via `.options()`
- [ ] Loading strategy chosen by the cardinality/parent-count matrix, not by default/habit
- [ ] No model defines `lazy="joined"` — strategy lives at the query site
- [ ] Bulk update/delete statements set `execution_options(synchronize_session=False)` on async sessions
- [ ] Deep-paging endpoints use keyset pagination; OFFSET reserved for shallow pagination
- [ ] No lazy-loaded relationship is accessed after the owning session has closed
- [ ] Complex analytical queries use CTEs instead of deeply nested subqueries
- [ ] Filter composition uses chained `.where()`, never string concatenation
- [ ] Repository methods return model instances or scalars, never raw driver rows
