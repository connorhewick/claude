# Structlog Instrumentation

Configure structlog so every log line is machine-parseable, carries request-scoped context
automatically, and never leaks sensitive data — in a service, not just a script.

---

## Overview

Standard-library `logging` produces unstructured text that's painful to search, aggregate, or
alert on; structlog produces key-value structured events — JSON in production, colored
human-readable output in development — that log aggregators can index and correlate directly. The
philosophy: **bind context once, let it propagate everywhere** — a request ID bound in middleware
at the start of a request should show up in every log line emitted anywhere in that request's call
stack, without threading a logger instance through every function signature. Get the processor
chain and `contextvars` propagation right once, and every subsequent log call is just an event name
plus structured fields.

## Core Concepts

**The processor chain is the whole architecture.** Each log call passes through an ordered list of
callables — each receiving and returning an event dict — before a final renderer turns it into
output. `merge_contextvars` must run first so request-scoped context is present for every later
processor to see; the renderer (`JSONRenderer` in production, `ConsoleRenderer` in development)
runs last. Custom enrichment (environment tag, sensitive-field masking, trace correlation) is just
another processor inserted before the renderer.

**Bound loggers carry context without parameter threading.** `log.bind(user_id=..., tenant_id=...)`
returns a new logger that includes those fields in every subsequent call — but for anything scoped
to an HTTP request rather than a single object's lifetime, prefer `contextvars` over manual
`.bind()` chains: it survives across `await` points and doesn't require passing a logger instance
down through every layer.

**`contextvars` is what makes "bind once per request" actually work.** Binding via
`structlog.contextvars.bind_contextvars()` in request middleware means every subsequent
`structlog.get_logger()` call anywhere in that request's execution — service layer, repository
layer, a background task spawned from it — automatically includes that context, with zero
parameter passing. Always `clear_contextvars()` at the start of each request; without it, context
from a previous request handled on the same event-loop task can leak into the next one.

**Event names are identifiers, not sentences.** `log.info("order_created", order_id=..., total=...)`
— a fixed, snake_case, string-literal event name plus structured fields — is what you search and
alert on in an aggregator. An f-string event name (`log.info(f"Created {count} items")`) collapses
the identifier into a blob that's different every time, defeating the entire point of structured
logging.

**Log level maps to operational meaning, not to how interesting the code author found the line.**
Repository-layer lookups belong at `debug` — useful for troubleshooting, too noisy for steady-state
production. Service-layer operations (start/end of a business action, external calls) belong at
`info`. Recoverable issues (retries, fallbacks) are `warning`; failures a user will notice are
`error`; `log.exception()` — which captures the traceback automatically — is for the unexpected
ones.

**User input is a value, never a key or an event name.** `log.info(user_input)` or
`log.info("event", **{user_key: user_value})` lets the caller control the event identifier or the
structure of the log line itself — a log-injection vector and a schema-stability hazard. User-
supplied data belongs exclusively as a *value* under a fixed key: `log.info("search_performed",
query=user_input)`.

**Sensitive fields need an active mask, not an assumption of absence.** Passwords, tokens, and
other credentials must never reach a log line — a custom processor that redacts known-sensitive
key names before the renderer runs is a mechanical safety net that doesn't depend on every call
site remembering not to log them. This is the same discipline `pydantic-schema-designer.md`
applies at the schema boundary (`SecretStr`/`exclude`) — apply it at the logging boundary too,
since a field excluded from an API response can still get logged inside a service method if
nothing guards the log processor chain.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Where does request-scoped context (request ID, user ID) live? | `structlog.contextvars` bound in middleware | Propagates automatically to every logger anywhere in the request, no parameter threading |
| Repository lookup, cache hit/miss, internal state transition? | `debug` | Useful for troubleshooting; too noisy for steady-state production at `info` |
| Business operation start/end, external API call? | `info` | The operational signal worth keeping by default |
| Retry, fallback, deprecated-path usage? | `warning` | Recoverable, but worth surfacing |
| Operation failed in a way the user will notice? | `error`, or `log.exception()` for unexpected ones | `log.exception()` captures the traceback automatically |
| Need JSON output in prod, readable output in dev? | One `configure_logging(json_output=...)` toggle, `JSONRenderer` vs `ConsoleRenderer` | One code path, environment-driven renderer choice |
| Third-party library logs (uvicorn, SQLAlchemy) need the same structure? | Route them through `ProcessorFormatter.wrap_for_formatter` | Otherwise only your own `structlog.get_logger()` calls get structured |
| A field might contain PII/secrets? | A masking processor before the renderer, plus schema-level `SecretStr`/`exclude` | Defense at both the API boundary and the logging boundary — either alone can be bypassed by a new call site |

## Workflow

1. **Add `configure_logging()`** to application startup (inside the `lifespan` handler — see
   `fastapi-service-generator.md` for the lifespan pattern — not scattered module-level calls).
2. **Add request-context middleware** that clears and rebinds `contextvars` at the start of every
   request, propagating a request ID via header.
3. **Replace `print()`/raw `logging.getLogger()` calls** with `structlog.get_logger(__name__)`.
4. **Bind user/tenant context** in the auth dependency once identity is resolved.
5. **Set log levels deliberately**: service layer at `info`, repository layer at `debug`.
6. **Add custom processors** for environment tagging and sensitive-field masking, ahead of the
   renderer in the chain.
7. **Verify JSON output** by running the service and inspecting stdout; confirm request IDs
   correlate across the log lines of a single request.

## Patterns

### Production configuration

```python
import logging
import structlog

def configure_logging(*, log_level: str = "INFO", json_output: bool = True) -> None:
    """Call once at startup (inside the lifespan handler), before any log calls."""
    shared_processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,     # must run first
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
        mask_sensitive_fields,                        # custom processor, before the renderer
    ]
    renderer = structlog.processors.JSONRenderer() if json_output else structlog.dev.ConsoleRenderer()

    structlog.configure(
        processors=[*shared_processors, structlog.stdlib.ProcessorFormatter.wrap_for_formatter],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        processors=[structlog.stdlib.ProcessorFormatter.remove_processors_meta, renderer],
    )
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(getattr(logging, log_level.upper()))

    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
```

### Request-context middleware

```python
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
import structlog

class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))

        structlog.contextvars.clear_contextvars()      # never leak the previous request's context
        structlog.contextvars.bind_contextvars(
            request_id=request_id, method=request.method, path=request.url.path,
        )

        log = structlog.get_logger()
        log.info("request_started")
        response = await call_next(request)
        log.info("request_completed", status_code=response.status_code)

        response.headers["X-Request-ID"] = request_id
        return response

app.add_middleware(RequestContextMiddleware)   # register early
```

### Service and repository layer logging levels

```python
log = structlog.get_logger()

class OrderService:
    async def create_order(self, data: OrderCreate) -> Order:
        log.info("creating_order", item_count=len(data.items))          # info: business op
        try:
            order = await self._repo.create(data)
            log.info("order_created", order_id=str(order.id), total=str(order.total))
            return order
        except InsufficientStockError as e:
            log.warning("order_failed_insufficient_stock", item_id=str(e.item_id))
            raise
        except Exception:
            log.exception("order_creation_failed")     # captures the traceback automatically
            raise

class ItemRepository:
    async def get_by_id(self, item_id: UUID) -> Item | None:
        item = await self._session.get(Item, item_id)
        if item is None:
            log.debug("item_not_found", item_id=str(item_id))           # debug: too noisy for info
        return item
```

### Binding user context post-authentication

```python
# In an auth dependency, after resolving the current user:
structlog.contextvars.bind_contextvars(
    user_id=str(current_user.id),
    tenant_id=str(current_user.tenant_id),
)
```

### Log injection prevention

```python
# DANGEROUS — caller controls the event name / key structure
log.info(user_input)
log.info("event", **{user_key: user_value})

# SAFE — fixed event name and key; user input is always a value
log.info("search_performed", query=user_input)
log.info("event", user_data=user_value)
```

### Sensitive-field masking processor

```python
SENSITIVE_KEYS = {"password", "token", "secret", "authorization", "api_key"}

def _redact(value):
    if isinstance(value, dict):
        return {k: ("***REDACTED***" if k.lower() in SENSITIVE_KEYS else _redact(v)) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_redact(v) for v in value]
    return value

def mask_sensitive_fields(logger, method_name, event_dict):
    # Recurses into nested dicts/lists — a sensitive key one level deep (e.g. logging a whole
    # `dict(request.headers)` that contains "authorization", or a bound context object with a
    # nested "password" field) is just as real a leak as a top-level one. A processor that only
    # checks top-level keys is not the "mechanical guarantee" it claims to be.
    for key in event_dict:
        if key.lower() in SENSITIVE_KEYS:
            event_dict[key] = "***REDACTED***"
        else:
            event_dict[key] = _redact(event_dict[key])
    return event_dict

def add_environment(logger, method_name, event_dict):
    event_dict["env"] = settings.ENVIRONMENT
    return event_dict
```

### Optional: distributed-trace correlation

If the service has a tracing setup (OpenTelemetry or otherwise), add trace/span IDs to every log
event so a log line correlates directly with the corresponding trace:

```python
from opentelemetry import trace

def add_trace_context(logger, method_name, event_dict):
    span = trace.get_current_span()
    if span.is_recording():
        ctx = span.get_span_context()
        event_dict["trace_id"] = format(ctx.trace_id, "032x")
        event_dict["span_id"] = format(ctx.span_id, "016x")
    return event_dict
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Log lines from one request bleed into another's search results | `clear_contextvars()` missing at request start | Always clear before rebinding, since async tasks can share an event-loop thread |
| A password/token shows up in aggregated logs | No masking processor; relying on call sites to remember | Add a `mask_sensitive_fields` processor ahead of the renderer — a mechanical guarantee, not a convention |
| Logs are unsearchable, event text differs every call | f-string used as the event name | Fixed snake_case event name string; put variable data in fields |
| A logging call becomes a log-injection vector | User input used as an event name or dict key | User input goes only in values, under fixed key names |
| Production logs are deafening | Repository/debug-level logs promoted to `info`, or logging inside tight loops | Repository at `debug`; log a summary after a loop, never per-iteration |
| Third-party library logs render as unstructured text next to your JSON | Library logging not routed through structlog's formatter | Use `ProcessorFormatter.wrap_for_formatter` in the chain |
| UUIDs/Decimals show up oddly in JSON output | Not converted before logging | Convert explicitly to `str` — JSON renderer handles str/int/float/bool/None natively |
| Logger instance threaded through every function signature | Avoiding `contextvars`, passing loggers as parameters instead | Use module-level `structlog.get_logger()` + `contextvars` for request-scoped data |

## Quality Checklist

- [ ] `configure_logging()` called once at startup, inside the lifespan handler
- [ ] `merge_contextvars` is the first processor in the chain
- [ ] Request-context middleware clears contextvars at the start of every request
- [ ] Request ID is bound and propagated via `X-Request-ID` on both inbound and outbound
- [ ] Event names are fixed snake_case string literals — never f-strings or user input
- [ ] Repository logs are `debug`; service logs are `info`; failures use `warning`/`error`/`exception` appropriately
- [ ] A masking processor redacts known-sensitive keys before the renderer runs
- [ ] UUIDs and Decimals are converted to `str` before logging
- [ ] No logging inside tight loops — summarize after, not per-iteration
- [ ] Third-party library logs are routed through structlog's formatter for consistent structure
