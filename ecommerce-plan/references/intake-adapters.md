# Data-entry maturity and intake adapters

Assess **per entity**. The services never know where data came from; only the adapter does.

| Level | Reality | Strategy |
|---|---|---|
| 1 Manual-only | Typed into an admin UI or on paper | Validation in the UI; bulk edit; templates |
| 2 Files | Spreadsheets, CSV, PDFs, emailed supplier lists | Managed drop folder/upload; one mapping profile per supplier; quarantine report |
| 3 Semi-structured | Scheduled exports from POS/accounting, not integrated | Scheduled file adapters; reconciliation reports |
| 4 API/webhook | Systems with real integration surfaces | Event-driven sync; retries; dead-letter queue |
| 5 Governed | ERP/PIM/MDM is master data | Treat as source of truth; own side is a read-optimised projection |

Move one entity up one level at a time, only when the manual cost justifies it.

## Adapter contract

Every adapter implements `extract → map → validate → load`:

- Maps into canonical Pydantic-style schemas; the canonical model is the contract.
- Idempotent upsert keyed on a stable external ID.
- Bad rows are **quarantined, never silently dropped or half-loaded**; each gets a reason a
  non-technical owner can act on.
- Provenance on every record: source, batch ID, row, timestamp.
- Declare the entity's source of truth and sync direction once.

## Checklist before adopting a new intake path

- [ ] Source of truth declared for this entity
- [ ] Stable external ID identified (or a key-generation rule agreed)
- [ ] Unit, currency and encoding rules written down
- [ ] Re-run of the same file proven harmless
- [ ] Quarantine report readable by the data owner
- [ ] Publish-readiness gate wired to the fix queue
