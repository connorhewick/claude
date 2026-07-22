# Pytest Patterns

Write pytest suites for async FastAPI/SQLAlchemy services that run fast, stay isolated, and
survive refactoring because they test behavior at boundaries rather than internal wiring.

---

## Overview

A test suite that's slow, flaky, or coupled to implementation details gets skipped, disabled in
CI, and eventually ignored entirely — at which point it stops catching anything. The patterns here
produce tests that run in milliseconds (transaction-rollback isolation, no real network), fail
with a clear message pointing at the actual behavior, and don't need rewriting every time an
internal method is renamed. The core discipline: **assert on outputs and observable side effects,
never on which internal methods got called in what order** — the latter tests the wiring, not the
behavior, and breaks on every honest refactor.

## Core Concepts

**Test behavior, not implementation.** Assert on HTTP status codes, response bodies, and stored
state — not on `mock.call_count` or which private method fired. A test that breaks because you
renamed `_calculate_discount` without changing what it returns is a test that was never testing
the right thing.

**Fixtures over setup/teardown methods.** pytest's fixture system is explicit and composable:
dependencies are declared as parameters, not implied by call order. Prefer function-scoped
fixtures for anything mutated per test and session-scoped fixtures only for expensive, immutable
setup (engine creation, app construction).

**Isolate at the transaction level, not by truncating tables.** Wrap each test's database access
in a transaction that rolls back at teardown. This is faster than dropping/recreating tables per
test and guarantees no test can see another's leftover data — order-independence is a property of
the isolation strategy, not of test-writing discipline.

**Prefer interface fakes over mocks for your own layers.** When the codebase follows an
interface-first architecture (see `fastapi-service-generator.md`), inject an in-memory class that
implements the same ABC instead of mocking methods on the concrete. A fake that satisfies the
interface catches contract violations that a mock silently ignores — reserve `mocker`/
`unittest.mock` for genuine external boundaries (a third-party HTTP API, the clock, an email
provider).

**Async tests need the loop configured once, not per test.** `pytest-asyncio`'s `asyncio_mode =
"auto"` in `pyproject.toml` lets every `async def test_...` run without individually decorating
`@pytest.mark.asyncio`. Choose one policy for the whole project and don't mix per-file overrides
without a documented reason.

**Parameterize instead of duplicating near-identical tests.** `pytest.param(..., id="...")` turns
a table of input/expected-output pairs into one test function with readable, individually
addressable failures — far more maintainable than five copy-pasted test bodies differing in one
literal.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Testing service-layer business logic? | Unit test with an interface fake repository | Fast, no DB, catches contract violations mocks miss |
| Testing a full request/response cycle? | Integration test via `httpx.AsyncClient` + `ASGITransport` | Exercises routing, DI, serialization together |
| Testing Pydantic validation rules? | Schema unit test, no async/DB needed | Pure, fastest tier — runs in microseconds |
| Need realistic ORM-object test data? | `factory_boy`/`SQLAlchemyModelFactory` | Persists to a real (test) session; good for repo/integration tests |
| Need realistic schema instances without a DB? | `polyfactory`'s `ModelFactory` for Pydantic models | Builds validated Pydantic instances directly |
| Mocking an external HTTP API/clock/email provider? | `pytest-mock`'s `mocker.patch` | Legitimate external boundary — nothing else to fake against |
| Many similar inputs testing the same code path? | `pytest.mark.parametrize` with `pytest.param(id=...)` | One test function, readable per-case failure output |
| Need the same test logic run against two implementations of an interface? | A shared contract test-mixin class, subclassed per implementation | Confirms both concretes satisfy the same behavior |
| Database isolation strategy? | Per-test transaction + rollback | Fast, no cross-test leakage, no table truncation needed |

## Workflow

1. **Identify the test boundary**: unit (service + fake), integration (API round-trip), or schema
   (pure Pydantic validation) — pick the cheapest tier that actually exercises the behavior.
2. **Check/build `conftest.py`** — session-scoped engine, function-scoped rollback session,
   `AsyncClient` fixture with `dependency_overrides` wired to the test session.
3. **Write the happy path first** — the most common real usage.
4. **Add edge cases** — empty input, boundary values, missing optional fields.
5. **Add error cases** — invalid input (422), not found (404), conflict (409), unauthorized (401).
6. **Parameterize** wherever multiple inputs exercise the same code path.
7. **Run and fix**: `pytest -x -v`, then check `pytest --cov` against the project's coverage floor.

## Patterns

### conftest.py — rollback-isolated async session + test client

```python
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from httpx import AsyncClient, ASGITransport

from app.main import create_app
from app.db.base import Base
from app.dependencies import get_session

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture(scope="session")
async def engine():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest_asyncio.fixture
async def session(engine):
    """Each test gets its own transaction that rolls back — fast, isolated."""
    async with engine.connect() as conn:
        transaction = await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)
        yield session
        await session.close()
        await transaction.rollback()

@pytest_asyncio.fixture
async def client(session):
    app = create_app()
    app.dependency_overrides[get_session] = lambda: session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
```

### Interface fakes over mocking internals

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

# tests/unit/services/test_payment_service.py
@pytest.fixture
def repo() -> FakePaymentRepository:
    return FakePaymentRepository()

async def test_create_payment_stores_entity(repo):
    service = PaymentService(repository=repo)
    request = PaymentCreateRequest(amount=Decimal("100.00"), currency="usd", reference="REF-001")

    response = await service.create_payment(request)

    assert response.reference == "REF-001"
    assert len(repo._store) == 1
```

### Test data factories

```python
# polyfactory — for Pydantic-schema-heavy tests
from polyfactory.factories.pydantic_factory import ModelFactory

class ItemCreateFactory(ModelFactory):
    __model__ = ItemCreate
    price = Decimal("29.99")

batch = ItemCreateFactory.batch(size=5)
custom = ItemCreateFactory.build(name="Custom Name")

# factory_boy — for ORM-persisted test data
import factory
from factory.alchemy import SQLAlchemyModelFactory

class ItemFactory(SQLAlchemyModelFactory):
    class Meta:
        model = Item
        sqlalchemy_session = None       # bound via fixture

    name = factory.Sequence(lambda n: f"Item {n}")
    price = factory.LazyFunction(lambda: Decimal("19.99"))

@pytest_asyncio.fixture
def item_factory(session):
    ItemFactory._meta.sqlalchemy_session = session
    return ItemFactory
```

### Integration test through the real HTTP stack

```python
async def test_create_order(client):
    # Arrange
    payload = {"items": [{"product_id": str(uuid4()), "quantity": 2}]}

    # Act
    response = await client.post("/api/orders", json=payload)

    # Assert
    assert response.status_code == 201
    assert response.json()["item_count"] == 1
```

### Mocking only a genuine external boundary

```python
async def test_order_sends_notification(mocker):
    mock_notify = mocker.patch(
        "app.services.notification.NotificationService.send",
        new_callable=mocker.AsyncMock,
    )

    service = OrderService(repo=FakeOrderRepository(), notifier=NotificationService())
    await service.create_order(data)

    mock_notify.assert_called_once_with(recipient=data.user_email, template="order_created")
```

### Parameterized validation tests

```python
@pytest.mark.parametrize(
    "input_data,expected_status,expected_error",
    [
        pytest.param({"name": "", "price": "10.00"}, 422, "min_length", id="empty-name"),
        pytest.param({"name": "Widget", "price": "-1.00"}, 422, "greater_than", id="negative-price"),
        pytest.param({"name": "Widget", "price": "10.00"}, 201, None, id="valid-input"),
    ],
)
async def test_create_item_validation(client, input_data, expected_status, expected_error):
    response = await client.post("/api/items", json=input_data)
    assert response.status_code == expected_status
    if expected_error:
        assert expected_error in str(response.json())
```

### Pure schema validation test (no async, no DB)

```python
from pydantic import ValidationError

class TestItemCreateSchema:
    def test_negative_price_rejected(self):
        with pytest.raises(ValidationError, match="greater_than"):
            ItemCreate(name="Widget", price=Decimal("-1.00"), category_id=uuid4())
```

### Coverage configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
markers = ["slow: deselect with '-m \"not slow\"'", "integration: marks integration tests"]

[tool.coverage.report]
exclude_lines = ["pragma: no cover", "if TYPE_CHECKING:", "if __name__ =="]
fail_under = 80
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Test breaks on a pure refactor with unchanged behavior | Asserting on `mock.call_count`/internal method calls | Assert on observable outputs (response body, stored state) |
| A test mocks five collaborators to check one behavior | Mock-heavy unit test testing the wiring, not the logic | Use an interface fake or an integration test with real dependencies |
| Flaky tests depending on run order | Shared mutable state (class attrs, session-scoped mutated fixtures) | Function-scoped fixtures; each test starts from a clean transaction |
| Tests pass alone, fail in the suite | Cross-test data leakage — no rollback isolation | Wrap DB access in a per-test transaction that always rolls back |
| `await asyncio.sleep(1)` littering async tests | Waiting for something async by sleeping instead of synchronizing on it | Use an `asyncio.Event`, mock the clock, or restructure the code under test |
| Testing that FastAPI returns 422 for malformed JSON | Testing framework behavior instead of your own validation | Test *your* validation rules and *your* error responses only |
| `DetachedInstanceError` mid-assertion | Session closed before a lazy relationship attribute was accessed | Eager-load what the test needs, or assert before closing the session |
| Private method directly unit-tested | `_calculate_discount()` tested in isolation | Test through the public interface; extract to a module function if it deserves standalone testing |

## Quality Checklist

- [ ] Every test follows Arrange / Act / Assert, visually separated
- [ ] Test names describe the scenario (`test_returns_404_when_order_not_found`), not the implementation
- [ ] Database tests use transaction rollback for isolation, not table truncation
- [ ] Mocks are reserved for genuine external boundaries; internal layers use interface fakes
- [ ] Parameterized tests use `pytest.param(id="...")` for readable per-case output
- [ ] No `time.sleep()`/`asyncio.sleep()` used to wait for async completion in a test
- [ ] Factories produce realistic data, not placeholder literals like `"string"` or `0`
- [ ] Fixtures are scoped correctly — session-scope only for expensive/immutable setup
- [ ] `conftest.py` holds shared fixtures; test-specific fixtures stay in the test file
- [ ] Coverage checked against the project's floor (`pytest --cov`), not assumed
