# FastAPI Service Generator

Scaffold production FastAPI services with strict layered architecture and ABC-based interfaces so
any component is swappable at the DI layer with zero changes to its callers.

---

## Overview

A production FastAPI service is seven thin layers stacked in one direction — API → schema →
interface → service → repository → model → client (database engine) — where every cross-layer
dependency is expressed as an abstract contract, not a concrete class. The philosophy: **type
against interfaces, wire concretes in exactly one file.** A service that depends on
`IPaymentRepository` rather than `PaymentRepository` doesn't care whether the concrete is
Postgres, an in-memory fake, or a Redis-backed cache — swapping it is a one-line change in
`dependencies.py`, not a refactor. This buys testability (inject a fake, not a mock), swappability
(hot-swap an implementation without touching business logic), and a codebase where "what talks to
what" is always visible in a type signature.

## Core Concepts

**Layers are a one-way dependency graph.** Routes depend on services (via `Depends()`), services
depend on repository *interfaces*, repositories depend on `AsyncSession`, and only the client layer
(`db/`) touches the engine. Never let a layer skip levels (a route importing a repository
directly) or point backward (a repository importing a service). If a shortcut would violate this,
that's a signal to flag it, not to route around it silently.

**Interfaces are the seam, not ceremony.** Every ABC in `interfaces/` exists because something on
the other side of it might change: the storage technology, the business logic, or the test double.
Define the interface first, then the concrete — this forces the contract's shape to be decided
before implementation details leak into it. A concrete class that has no second implementation and
no test double swapped in is a smell: check whether the interface is pulling weight or just
indirection.

**Generic base classes eliminate CRUD boilerplate; interfaces eliminate implementation lock-in —
they solve different problems.** `BaseRepository[T]` gives every domain repository `get_by_id`,
`create`, `update`, `delete` for free via inheritance — use it when the *same* implementation
(SQLAlchemy) just needs the same CRUD shape repeated per entity. An ABC interface
(`IPaymentRepository`) exists when *different* implementations of the same contract need to be
swappable (Postgres today, Redis cache tomorrow, an in-memory fake in tests). Most repositories
need both: inherit `BaseRepository[T]` for CRUD, implement a domain interface for the swap point.

**The client layer is the only thing that knows about the engine.** `db/client.py` owns
`AsyncEngine` creation, pooling, and lifecycle; `db/session.py` turns that into an
`async_sessionmaker`; everything downstream — repositories, services, routes — receives only an
`AsyncSession`, injected via `Depends()`. This means swapping Postgres for an in-memory SQLite
engine in tests requires instantiating a different `DatabaseClient`, not monkey-patching internals.

**Mixins compose orthogonal capabilities; inheritance chains model "is-a."** `UUIDPrimaryKeyMixin`,
`TimestampMixin`, and `SoftDeleteMixin` are unrelated concerns that many models want simultaneously
— compose them (`class Payment(UUIDPrimaryKeyMixin, TimestampMixin, Base)`). Reserve deeper
concrete-to-concrete inheritance for genuine specialization, and cap it at one level; beyond that,
prefer an interface plus delegation. A subclass overriding more than about half of its parent is a
sign the abstraction is wrong, not that it needs another override.

**Money needs exact arithmetic; PII needs to stay out of routine paths.** Represent monetary
amounts as `Decimal` with an explicit `Numeric(precision, scale)` column — floats silently lose
cents at scale. Treat any field that identifies a person (email, SSN-equivalent, tokens) as
something the schema and logging layers must actively protect (`SecretStr`, field `exclude`, no
raw dumps in logs) rather than something that flows through by default — see
`pydantic-schema-designer.md` and `structlog-instrumentation.md` for the schema- and log-side
mechanics.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Same tech, new entity needing standard CRUD | Inherit `BaseRepository[T]` | CRUD is generic; only domain queries differ |
| Same contract, different backing tech (Postgres vs Redis vs in-memory) | ABC interface (`IRepository` subtype) | Callers depend on the contract, not the storage choice |
| Business logic that varies by product/tenant/region | ABC interface on the *service* | Swappable rules without touching callers |
| Orthogonal model capability (timestamps, soft delete, UUID PK) | Mixin | Composable, no forced "is-a" hierarchy |
| Concrete subclass overrides most of its parent | Redesign — don't inherit | >50% override means the abstraction is wrong |
| Need the new entity's session | `Depends(get_db_session)` from `dependencies.py` | Session lifecycle belongs to the client layer alone |
| Business rule needs to be swappable independent of storage | Separate service-level ABC from the repository ABC | Conflating the two makes neither swappable alone |
| Testing a repository | Interface fake (in-memory class implementing the ABC) | Faster and more honest than mocking internals |

## Workflow

1. **Project discovery.** Detect the stack (`pyproject.toml`), existing layer directories
   (`api/`, `services/`, `repositories/`, `models/`, `schemas/`, `interfaces/`, `db/`,
   `dependencies.py`), and whether ABCs are already in use. Read any `CLAUDE.md`/`ARCHITECTURE.md`.
2. **Model layer**: define the SQLAlchemy model with `Mapped[]` typed columns, composing mixins
   for shared capabilities (`models/mixins.py`).
3. **Schema layer**: define the Create/Update/Read/Filter family — see
   `pydantic-schema-designer.md` for the full pattern.
4. **Interface layer**: define `I{Domain}Repository(IRepository[T])` in `interfaces/`, adding only
   domain-specific method signatures beyond the generic CRUD contract.
5. **Repository layer**: implement it extending `BaseRepository[T]` for CRUD, adding
   domain-specific queries — see `sqlalchemy-query-patterns.md` for query construction.
6. **Service layer**: implement business logic typed against the *interface*, never the concrete
   repository class.
7. **DI wiring**: add `Depends()`-based provider functions in `dependencies.py` — the single file
   that imports concrete implementations.
8. **API layer**: add router endpoints that depend on the service via `Depends()` only.
9. **Observability**: add `structlog` calls at service (info) and repository (debug) boundaries —
   see `structlog-instrumentation.md`.
10. **Tests**: unit tests against an interface fake, integration tests through the real HTTP
    stack — see `pytest-patterns.md` and the fakes pattern below.
11. **Self-review** against the Quality Checklist below before calling it done.

## Patterns

### Generic interface + domain interface

```python
# interfaces/base.py
from abc import ABC, abstractmethod
from typing import Generic, TypeVar
from uuid import UUID

T = TypeVar("T")

class IRepository(ABC, Generic[T]):
    @abstractmethod
    async def get_by_id(self, id: UUID) -> T: ...
    @abstractmethod
    async def create(self, entity: T) -> T: ...
    @abstractmethod
    async def update(self, entity: T) -> T: ...
    @abstractmethod
    async def delete(self, id: UUID) -> None: ...

# interfaces/payment_repository.py
class IPaymentRepository(IRepository["Payment"]):
    @abstractmethod
    async def get_by_reference(self, reference: str) -> "Payment": ...
```

### Generic base repository + domain repository

```python
# repositories/base.py
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Generic, TypeVar, Type
import structlog

T = TypeVar("T")
log = structlog.get_logger(__name__)

class BaseRepository(IRepository[T], Generic[T]):
    model_class: Type[T]                         # set by subclass

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, id: UUID) -> T:
        result = await self._session.get(self.model_class, id)
        if result is None:
            raise EntityNotFoundError(entity=self.model_class.__name__, id=id)
        return result

    async def create(self, entity: T) -> T:
        self._session.add(entity)
        await self._session.flush()
        await self._session.refresh(entity)
        log.info("repo.created", model=self.model_class.__name__, id=str(entity.id))
        return entity

# repositories/payment_repository.py — CRUD inherited, only domain queries added
class PaymentRepository(BaseRepository[Payment], IPaymentRepository):
    model_class = Payment

    async def get_by_reference(self, reference: str) -> Payment:
        result = await self._session.execute(select(Payment).where(Payment.reference == reference))
        payment = result.scalar_one_or_none()
        if payment is None:
            raise PaymentNotFoundError(reference=reference)
        return payment
```

### Service typed against the interface

```python
# services/payment_service.py
class PaymentService:
    """Typed against IPaymentRepository — swap the concrete in dependencies.py only."""
    def __init__(self, repository: IPaymentRepository) -> None:
        self._repository = repository

    async def create_payment(self, request: PaymentCreateRequest) -> PaymentResponse:
        log.info("payment.service.create", amount=str(request.amount), currency=request.currency)
        payment = Payment(amount=request.amount, currency=request.currency, reference=request.reference)
        payment = await self._repository.create(payment)
        return PaymentResponse.model_validate(payment)
```

### Mixin composition for models

```python
# models/mixins.py
class UUIDPrimaryKeyMixin:
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

# models/payment.py
class Payment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "payments"
    amount: Mapped[Decimal] = mapped_column(Numeric(precision=18, scale=2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    reference: Mapped[str] = mapped_column(String(64), unique=True, index=True)
```

### Client layer: engine lifecycle via lifespan (not `@app.on_event`)

```python
# db/client.py — sole owner of the engine
class DatabaseClient:
    def __init__(self, url: str, echo: bool = False) -> None:
        self._url, self._echo, self._engine = url, echo, None

    async def connect(self) -> None:
        self._engine = create_async_engine(self._url, echo=self._echo, pool_pre_ping=True)

    async def disconnect(self) -> None:
        if self._engine:
            await self._engine.dispose()

# main.py — lifespan context manager is the only supported startup/shutdown hook;
# the deprecated @app.on_event("startup"/"shutdown") decorators should not appear in new code
@asynccontextmanager
async def lifespan(app: FastAPI):
    await db_client.connect()
    app.state.session_factory = create_session_factory(db_client)
    yield
    await db_client.disconnect()

def create_app() -> FastAPI:
    return FastAPI(lifespan=lifespan)
```

### DI wiring: the one file that imports concretes

```python
# dependencies.py
def get_payment_repository(session: AsyncSession = Depends(get_db_session)) -> IPaymentRepository:
    return PaymentRepository(session)          # swap this line to hot-swap the backend

def get_payment_service(repo: IPaymentRepository = Depends(get_payment_repository)) -> PaymentService:
    return PaymentService(repo)
```

### Interface fake for tests (no mocking library needed)

```python
# tests/fakes/payment_repository.py
class FakePaymentRepository(IPaymentRepository):
    def __init__(self) -> None:
        self._store: dict[UUID, Payment] = {}

    async def create(self, entity: Payment) -> Payment:
        entity.id = uuid4()
        self._store[entity.id] = entity
        return entity

    async def get_by_reference(self, reference: str) -> Payment:
        for p in self._store.values():
            if p.reference == reference:
                return p
        raise PaymentNotFoundError(reference=reference)

# The service under test never knows it's talking to a fake:
service = PaymentService(repository=FakePaymentRepository())
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Route breaks when the repository's internals change | Route imports the repository directly instead of the service | Routes depend only on services, via `Depends()` |
| Swapping storage backend touches a dozen files | Service typed against the concrete class, not the interface | Type constructor args as the ABC interface |
| Tests mock five internal collaborators to test one behavior | Mocking implementation details instead of injecting a fake | Implement an in-memory class satisfying the interface |
| `DetachedInstanceError` on a relationship access | Session already closed when the lazy attribute was touched | Eager-load what's needed before the session ends (see `sqlalchemy-query-patterns.md`) |
| Engine accessed outside `db/` | A repository or service imports `AsyncEngine`/`create_async_engine` directly | Only the client layer touches the engine; everything else gets `AsyncSession` |
| Deep inheritance chains that are hard to reason about | Concrete-to-concrete inheritance used for unrelated logic sharing | Cap concrete inheritance at one level; use composition or an interface instead |
| Monetary totals drift by cents at scale | `float` used for money instead of `Decimal` | `Decimal` with `Numeric(precision, scale)` end to end |
| Startup/shutdown logic scattered or using `@app.on_event` | Legacy event-hook style instead of a lifespan context manager | Consolidate into one `lifespan()` async context manager |
| A field with sensitive data shows up in a log line or API response | No exclusion at the schema layer | `SecretStr`/`exclude` in the schema; audit what a Read schema actually returns |

## Quality Checklist

- [ ] Every cross-layer dependency is typed as an interface (ABC), not a concrete class
- [ ] `IRepository` and domain interfaces live in `interfaces/`; both sides of the contract import from there
- [ ] `BaseRepository[T]` supplies CRUD; domain repositories add only domain-specific methods
- [ ] `dependencies.py` is the only file importing concrete repository/service implementations
- [ ] Routes never import repositories directly — only services, via `Depends()`
- [ ] Repositories raise domain exceptions only, never `HTTPException`
- [ ] All models use `Mapped[]` typed columns (SQLAlchemy 2.x)
- [ ] `structlog.get_logger(__name__)` present in every module that logs
- [ ] Fully async (`async def`, `AsyncSession`) end to end
- [ ] `DatabaseClient` instantiated once, wired via `lifespan`, stored on `app.state` — no module-level engine
- [ ] Repositories never import `AsyncEngine`/`create_async_engine` — only the client layer does
- [ ] Monetary fields use `Decimal`/`Numeric`; sensitive fields use `SecretStr`/`exclude`
- [ ] New entities ship with unit tests (fakes) and an integration test (HTTP round-trip)
- [ ] Significant or hard-to-reverse layering/interface decisions are recorded with this repo's `write-adr` skill
