---
paths:
  - "**/migrations/**"
  - "**/migration/**"
  - "**/migrate/**"
  - "**/alembic/**"
  - "**/db/schema*"
  - "**/*.sql"
  - "**/*.prisma"
  - "**/api/**"
  - "**/routes/**"
  - "**/controllers/**"
  - "**/handlers/**"
  - "**/endpoints/**"
  - "**/*.{proto,graphql,gql}"
  - "**/{openapi,swagger}*.{yaml,yml,json}"
  - "**/schema*.{ts,js,py,rb,graphql,json}"
  - "**/*.schema.json"
  - "**/events/**"
  - "**/messages/**"
  - "**/*.{avsc,avdl,thrift,capnp}"
  - "**/asyncapi*.{yaml,yml,json}"
---

# Published contracts and schema migrations

A contract is published once something you don't control reads it: another service, a shipped
client, a stored record, a queued message. A migration runs once, on data you can't see, while the
system serves traffic.

## Wire shape

- **Add a field freely; removing, renaming or retyping one is breaking**, as is narrowing a
  type, making an optional field required, changing a default or what a value means, or adding
  an enum case consumers switch on exhaustively.
- **Additive wins over a clean breaking change** unless every consumer is known and reachable.
- **A breaking change needs all four, stated in the PR**: a migration path per consumer, a
  deprecation window with the old shape warning, a version at the boundary, and removal as its
  own later change.
- **Pin the shape** with a snapshot test that fails in both directions. Red because something
  was added: update the pin. Red because something was removed, renamed or retyped: fix the
  code, never the pin.

## Schema

- **Expand, migrate, contract — each its own migration and PR.** Backfill is batched, resumable
  and idempotent, never in the schema change's transaction. Contract comes in a later release,
  after every reader has moved.
- **A migration runs against the previous release's code.** Dropping, renaming or narrowing what
  running code reads is an outage during the deploy. Not-null: add nullable, backfill, constrain.
- **State the lock and its duration**, estimated against the real row count. Say if it is
  irreversible and what is lost; a silent no-op `down` is a trap.
- **Never edit a migration that has run anywhere.** Write the next one.
- A migration holds no business logic that also lives in code; copy the rule as of that day and
  name the source in the commit message. Test on production-shaped data, not the empty database.

## In the PR

`## Architecture changes` names the contract or tables touched, additive or breaking, which
migration step this is, the lock taken, and the release the contract step is planned for.
"No contract change" is worth writing.
