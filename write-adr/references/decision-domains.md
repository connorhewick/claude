# Decision domains

Stack-agnostic lookup of common architectural decision domains and their typical concrete
options. Use this only when the user hasn't already supplied at least two alternatives
themselves — propose options from the matching row below and confirm them with the user before
running the trade-off analysis. Don't treat a row as exhaustive or as a ranking; it's a prompt
for plausible alternatives, not a recommendation.

| Decision domain | Common options |
|---|---|
| Datastore | PostgreSQL, MySQL, DynamoDB, MongoDB, SQLite |
| Message queue | Kafka, RabbitMQ, SQS, Redis Streams, NATS |
| API style | REST, GraphQL, gRPC, JSON-RPC |
| Auth | OAuth2/OIDC, session cookies, JWT, SAML, API keys |
| Deployment | Containers on Kubernetes, serverless/FaaS, VMs, PaaS |
| Service communication | Synchronous HTTP/gRPC, async messaging/events, shared database |
| Frontend state | Global store (Redux/Zustand-style), server-state cache (React Query-style), component-local state, URL/route state |
| Caching | In-process cache, Redis/Memcached, CDN edge cache, database-level cache |
| Architecture pattern | Monolith, modular monolith, microservices, event-driven |
| Monorepo/polyrepo | Single monorepo, one repo per service, hybrid (core + satellites) |
| Observability | Structured logging only, logs + metrics, full tracing (logs + metrics + traces) |
| Task queue | Cron/scheduled jobs, in-process background workers, dedicated task queue (Celery/Sidekiq-style), managed workflow engine |

Keep this file technology-generic. A language- or framework-specific extension (e.g. a
Python-specific decision-domains reference) is out of scope here — if one is wanted, add it
alongside the relevant stack-specific skill instead, following the same pattern as
`python-engineering`/`java-engineering`'s own reference files.
