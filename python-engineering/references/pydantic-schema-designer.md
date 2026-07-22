# Pydantic Schema Designer

Design Pydantic v2 models that act as a service's contract layer — validating at the edge,
documenting themselves, and never leaking storage details into the API.

---

## Overview

Schemas are the boundary where untrusted input becomes trusted data, and where internal models
become an API's public shape. Pydantic v2 lets you push business rules into the type system
(`Literal`, discriminated unions, constrained types) so invalid states are unrepresentable rather
than checked at runtime, and its `model_config`/JSON Schema integration means FastAPI's generated
OpenAPI docs are accurate by construction rather than by discipline. The philosophy: **validate at
the edge, trust inside** — inbound schemas (Create/Update) carry the validation weight; outbound
and internal schemas assume the data is already clean and focus on shape, not re-checking it.

## Core Concepts

**Schemas are not ORM models — map between them explicitly.** Never inherit a Pydantic schema
from a SQLAlchemy model or vice versa. A schema that inherits from `ItemDBModel` couples the API
contract to storage: renaming a column silently breaks the API. Construct Read schemas from ORM
instances via `model_config = ConfigDict(from_attributes=True)` and `ItemRead.model_validate(db_item)`
— an explicit, one-directional conversion.

**One schema per boundary, not one universal model.** A single schema trying to serve Create,
Update, and Read inevitably grows an `Optional` on every field (Update needs partial data) or
leaks server-generated fields into the input side (Create shouldn't accept `id`/`created_at`).
Split into a schema family: `{Entity}Base` for shared fields, `{Entity}Create` for inbound
creation, `{Entity}Update` with every field optional (deliberately *not* inheriting from `Base`,
since inheriting required fields defeats the purpose of a partial update), `{Entity}Read` for
output, and `{Entity}Filter` for list/query parameters when they don't map cleanly to entity
fields.

**Make invalid states unrepresentable.** Prefer `Literal`, `Enum`, constrained `Field()` bounds,
and discriminated unions over runtime `if` checks. A field typed `Literal["email", "sms",
"webhook"]` cannot hold a fourth value — the type checker and Pydantic both enforce it before your
code ever runs. This shifts a class of bugs from "caught in production" to "caught at the type
boundary."

**Prefer `Annotated` constraint aliases over repeated inline constraints.** Defining
`PositiveDecimal = Annotated[Decimal, Field(gt=0, decimal_places=2)]` once and reusing it keeps
constraints DRY and makes them grep-able. Repeating `Field(gt=0, decimal_places=2)` across a dozen
schemas means a constraint change requires finding every occurrence.

**Discriminated unions beat untagged unions whenever a type tag exists.** Given a field that can
hold one of several shapes, tagging each variant with a `Literal` discriminator field lets Pydantic
validate against exactly the matching model instead of trying every variant in order — faster, and
the resulting `ValidationError` names the specific variant that failed rather than a confusing
"didn't match any of 3 types" message. The common current form is
`Annotated[Union[...], Field(discriminator="type")]`; reach for the `Discriminator(callable)` form
only when the tag isn't a plain literal field (e.g. it's derived from a nested value) — verify
which your Pydantic version needs before assuming the callable form is required.

**Coercion is a decision, not a default to accept passively.** Without `strict=True`, Pydantic
silently coerces `"123"` → `123`, and similar cross-type conversions — convenient for query
parameters, dangerous for anything where a type mismatch should be a caught bug. Set
`ConfigDict(strict=True)` as the project default and relax it explicitly, per field, where
coercion is genuinely wanted (e.g., accepting `"true"` as a bool from a query string).

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Constructing from a SQLAlchemy instance? | `model_config = ConfigDict(from_attributes=True)` on the Read schema | Explicit, one-directional ORM→schema mapping; no inheritance coupling |
| Partial update endpoint (PATCH-style)? | Standalone `{Entity}Update` with every field optional, not inheriting `Base` | Inheriting required fields defeats a partial update's purpose |
| A field can be one of several tagged shapes? | Discriminated union (`Field(discriminator=...)`) | Faster validation, precise error messages, vs. an untagged `Union` trying every variant |
| Same constraint used across multiple schemas? | `Annotated` type alias, reused | DRY, discoverable via grep, one place to change the rule |
| Cross-field business rule (end date ≥ start date)? | `@model_validator(mode="after")` | Has access to all fields already validated individually |
| Single-field transform/normalization? | `@field_validator` | Scoped to one field; use `mode="before"` only to pre-process raw input |
| Should this schema re-validate already-clean data? | No — trust it (Read/internal DTOs) | Validation belongs at the inbound edge; re-validating internally is redundant work |
| Field holds a derived/computed value for output only? | `@computed_field` | Appears in serialized output and OpenAPI without being a stored/settable field |
| Field is sensitive (token, password, PII)? | `SecretStr` or `exclude=True` | Prevents accidental inclusion in `.model_dump()`/JSON/logs |

## Workflow

1. **Identify the domain entity** and its boundaries — which endpoints and services consume it.
2. **Map the schema family**: Create, Update, Read, Filter, internal DTO — skip whichever this
   entity doesn't need.
3. **Define field constraints** with `Field()` and `Annotated` aliases before reaching for custom
   validators.
4. **Add validators only where `Field()` constraints fall short** — cross-field rules, conditional
   logic, external lookups.
5. **Set `model_config`**: `from_attributes=True` on Read schemas that construct from ORM
   instances; `frozen=True` on Read/internal schemas to prevent accidental downstream mutation;
   `strict=True` as the project default.
6. **Add `description`s and `json_schema_extra` examples** — they feed OpenAPI directly.
7. **Mark sensitive fields** `SecretStr`/`exclude` before the schema goes anywhere near a route.
8. **Review against the Quality Checklist** below.

## Patterns

### Schema family for one entity

```python
from pydantic import BaseModel, ConfigDict, Field
from decimal import Decimal
from uuid import UUID
from datetime import datetime

class ItemBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Display name")
    description: str | None = Field(default=None, max_length=2000)

class ItemCreate(ItemBase):
    price: Decimal = Field(..., gt=0, decimal_places=2)
    category_id: UUID

class ItemUpdate(BaseModel):                 # NOT ItemBase — every field optional
    name: str | None = Field(default=None, min_length=1, max_length=255)
    price: Decimal | None = Field(default=None, gt=0, decimal_places=2)
    category_id: UUID | None = None

class ItemRead(ItemBase):
    model_config = ConfigDict(from_attributes=True, frozen=True)
    id: UUID
    price: Decimal
    category_id: UUID
    created_at: datetime
    updated_at: datetime

class ItemFilter(BaseModel):                 # query semantics differ from entity fields
    category_id: UUID | None = None
    min_price: Decimal | None = Field(default=None, ge=0)
    search: str | None = Field(default=None, max_length=200)
```

### Reusable constrained type aliases

```python
from typing import Annotated
from pydantic import Field

NameStr = Annotated[str, Field(min_length=1, max_length=255)]
PositiveDecimal = Annotated[Decimal, Field(gt=0, decimal_places=2)]
PageSize = Annotated[int, Field(ge=1, le=100)]
```

### Validators: field-level and cross-field

```python
from pydantic import field_validator, model_validator

class UserCreate(BaseModel):
    username: str

    @field_validator("username")
    @classmethod
    def normalize_username(cls, v: str) -> str:
        return v.strip().lower()          # always return the (possibly transformed) value

class DateRangeFilter(BaseModel):
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def end_after_start(self) -> "DateRangeFilter":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be >= start_date")
        return self
```

### Discriminated union

```python
from typing import Literal, Union, Annotated
from pydantic import BaseModel, Field

class EmailNotification(BaseModel):
    type: Literal["email"]
    to: str
    subject: str

class SMSNotification(BaseModel):
    type: Literal["sms"]
    phone: str
    message: str = Field(max_length=160)

Notification = Annotated[
    Union[EmailNotification, SMSNotification],
    Field(discriminator="type"),           # the current idiomatic shorthand
]

class EventConfig(BaseModel):
    notifications: list[Notification]
```

### Computed field for derived output

```python
from pydantic import computed_field

class OrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    subtotal: Decimal
    tax_rate: Decimal

    @computed_field
    @property
    def total(self) -> Decimal:
        return self.subtotal * (1 + self.tax_rate)
```

### model_config in practice

```python
from pydantic import ConfigDict

class StrictSchema(BaseModel):
    model_config = ConfigDict(
        strict=True,                 # no silent coercion — project default
        frozen=True,                 # immutable after creation
        from_attributes=True,        # construct from ORM objects
        json_schema_extra={"examples": [{"name": "Widget", "price": "9.99"}]},
    )
```

### Protecting sensitive fields

```python
from pydantic import SecretStr

class UserCreate(BaseModel):
    email: str
    password: SecretStr                        # never renders in repr/str/JSON by default

class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    api_token: str | None = Field(default=None, exclude=True)  # never serialized outbound
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| One schema with a dozen `Optional` fields serving Create, Update, and Read | God schema covering every boundary at once | Split into the Create/Update/Read/Filter family |
| API breaks when a DB column is renamed | Schema inherits directly from the ORM model | Map explicitly with `from_attributes=True` + `model_validate` |
| Cross-field validation scattered across multiple `@field_validator`s | Validator spaghetti — multi-field logic forced into single-field hooks | Move it to one `@model_validator(mode="after")` |
| `"123"` accepted where an `int` was intended, bug surfaces downstream | No `strict=True`; Pydantic silently coerced | Set `strict=True` project-wide; relax only where coercion is intentional |
| Union field fails validation with a confusing "no match" error | Untagged `Union` used where variants have a natural tag | Discriminated union with `Field(discriminator=...)` |
| Sensitive field appears in a log line or API response | No `SecretStr`/`exclude` on the field | Mark it explicitly; audit every Read schema for what it actually returns |
| Downstream code mutates a "read-only" response object | Read schema not marked `frozen=True` | Set `frozen=True` on Read/internal DTOs |
| OpenAPI docs are technically correct but unhelpful | No `description`/`examples` on fields | Add `description` to every field; add `json_schema_extra` examples |

## Quality Checklist

- [ ] Create and Update schemas are separate — Update does not inherit from a required-fields base
- [ ] Read schemas use `from_attributes=True` when constructed from ORM instances
- [ ] No schema inherits from a SQLAlchemy model, in either direction
- [ ] `strict=True` is the default; coercion is opt-in per field
- [ ] Discriminated unions are used wherever a natural type-tag field exists
- [ ] Every field carries a `description`; representative examples are set via `json_schema_extra`
- [ ] Validators always return the (possibly transformed) value and raise `ValueError` with a clear message
- [ ] Repeated constraints are factored into reusable `Annotated` aliases
- [ ] Sensitive fields use `SecretStr` or `exclude=True`
- [ ] Read/internal DTOs are `frozen=True` to prevent accidental downstream mutation
- [ ] No circular imports between schema modules
