# Size profiles

Defaults, not mandates. Override when the profile card says otherwise.

## Sizing

Classify by whichever dimension is the **stronger constraint**: a 3-person shop shipping 5,000
orders a month is operationally small or medium, not micro. Thresholds are indicative.

| | Micro | Small | Medium |
|---|---|---|---|
| Headcount | 1–5 | 5–50 | 50–500 |
| Orders/month | < ~100 | ~100–2,000 | > ~2,000 |
| Products (SKUs) | < ~100 | ~100–2,000 | > ~2,000 |

## Defaults per size

| | Micro | Small | Medium |
|---|---|---|---|
| Reality | Owner does everything; spreadsheets; hosted storefront | A few specialists; POS or accounting package; some manual ops | Departments; ERP/WMS; integrations; compliance |
| Posture | **Buy and configure.** Hosted platform + plugins; custom code only for intake scripts | **Buy core, build seams.** SaaS storefront + thin service layer for sync and rules | **Build differentiators, integrate the rest.** Own order/inventory/pricing services; buy payments, tax, search |
| Infra | Managed everything | Managed DB/containers, one pipeline | CI/CD, staging, observability stack, on-call |
| Governance | One-page decision log | Lightweight ADRs; named owner per integration | ADRs, change control, security/compliance review |
| Release | Small batches, manual smoke test | Feature flags; canary on one channel | Staged canary with automatic rollback |
| Horizon | Weeks | 1–2 quarters | Multi-quarter roadmap |

## Loop depth per phase

Phases 1–4 are carried out during the pass; phases 5–7 describe the depth to plan for.

| Phase | Micro | Small | Medium |
|---|---|---|---|
| Baseline | 4 numbers from the platform dashboard (orders/month, conversion, AOV, admin hours/week) | Funnel by channel, error rate, order-to-ship time, support tickets | Funnel by segment/cohort, margin per channel, SLOs, cost-to-serve |
| Find the leak | Owner buys their own product end to end | Session recordings, support-ticket themes | Experiment backlog, data-driven prioritisation |
| Supply audit | Is the sheet trustworthy enough to publish from? | Source-of-truth matrix + quality profile (duplicates, missing fields, unit/currency) | Master-data governance, SLAs with system owners |
| Design | Tool choice + config checklist | Build/buy table, offer schema, intake mapping | Context boundaries, event contracts, ADRs, migration plan |
| Build | Configure; script the one painful import | Adapters + thin service seam behind a flag | Services, contract tests, channel adapters |
| Verify | Real test orders on real payment methods | Plus duplicate upload, oversell, webhook replay | Plus load, failure injection, security/compliance review |
| Release | Switch in a quiet week | Canary on one channel/supplier | Staged canary, auto-rollback, retro against SLOs |
