---
name: ecommerce-plan
description: Produce a repeatable, size-adaptive plan for improving or enabling a business's online commerce offering (micro, small, or medium business; any mix of manual, file, or API data entry). Explicit `/ecommerce-plan` only — never auto-triggered. Not for single-feature implementation, a PRD (write-prd), or a feature-level design (write-tdd).
argument-hint: >
  [business-name or short context]
disable-model-invocation: true
---

# E-commerce improvement plan

Produces one plan document for **one pass** of an improvement loop. The loop is meant to be
re-run: each pass moves one rung up the online ladder or hardens the current one, then the plan
is regenerated against fresh baselines.

The online offer is the product; the core business is its supply chain. Back-office data depth
is set by what the storefront needs, not by what the business holds.

## 1. Classify (ask, don't assume; infer from context already given)

Establish the **profile card** before planning anything:

1. **Size** — micro / small / medium. Defaults per size: `references/profiles.md`.
2. **Online level** — L0 no presence → L4 optimised. Definitions and capability checklist:
   `references/online-ladder.md`.
3. **Data-entry maturity, per entity** (products, stock, prices, customers, orders) — manual →
   files → semi-structured → API → governed. Strategies: `references/intake-adapters.md`.
4. **Offer type** — physical goods, services/bookings, or digital goods/subscriptions (swaps the
   fulfilment promise for entitlement delivery and adds recurring billing).

Write the card at the top of the plan, e.g. `Small × L1 × catalog: files, stock: manual`.
Different entities legitimately sit at different maturity levels.

## 2. Architecture stance

Same layered core at every size; variation lives in two seams.

```
Channels      own storefront · marketplaces · feeds · B2B/quote form
Experience    storefront API: catalog, search, cart, checkout, account, order status
Commerce      Offer · Cart/Checkout · Orders · Payments · Fulfilment promise
Repository    one repo per aggregate
Intake        adapters → canonical schemas → validation → quarantine (varies per business)
Platform      structured logging with correlation + batch IDs, analytics events,
              feature flags, jobs/outbox, migrations
```

- Central entity is the **sellable offer** (item, price, availability, promise, content/SEO).
- **Publish-readiness gate**: incomplete offers stay unpublished and land in a fix queue.
- Channels are outbound adapters on one offer model. Source of truth is declared per entity.
- Per-context **build / buy / defer** decision comes from the size profile; contexts stay
  swappable behind service interfaces.

## 3. Run the loop (depth per size in `references/profiles.md`)

Funnel: **Discover → Evaluate → Buy → Receive → Return/Repeat.** Target the weakest stage.

1. **Baseline** — funnel and operations numbers (templates: `references/templates.md`).
2. **Find the leak** — biggest drop-off or cost in the funnel.
3. **Supply-readiness audit** — can the business reliably supply a complete, correct offer?
   Produce the source-of-truth matrix.
4. **Design** — channel/platform choice, canonical offer, intake mapping, checkout and promise
   rules, build/buy table. Record significant decisions via `write-adr` rather than inline.
5. **Build behind a flag** — smallest change that moves the metric.
6. **Verify as a customer** — browse, buy, pay, ship, refund, plus failure cases.
7. **Release & measure** — controlled rollout; compare with baseline; retire the old path.

Prioritise by hours saved and errors removed for micro/small; by risk-adjusted revenue and
scale for medium. Don't impose structure the business can't sustain: a micro seller maintaining
stock in a sheet gets a validated upload and a clear error report, not a mandatory API.

## 4. Guardrails (every size)

- Money as `Decimal`/integer minor units with explicit currency.
- Checkout, imports and webhooks are idempotent; re-uploading yesterday's file is harmless.
- Stock decrements are atomic; the published promise never exceeds reality.
- Payment state is a state machine; provider webhooks are reconciled, not trusted.
- Every record keeps provenance (source, batch, timestamp); every rejected row gets a
  human-readable fix path.
- No card data in your own scope — hosted fields or tokens.
- Every release has a documented rollback.

## 5. Output

Write the plan to `docs/ecommerce-plan/<YYYY-MM-DD>-<short-title>.md` (create the directory if
needed) with: profile card, funnel baseline, selected target and rationale, supply-readiness
findings, build/buy/defer table, phased steps with exit gates, risks, and the metric that
defines this pass as done. End with the **next-pass trigger**: what result moves the business to
the next rung or next entity maturity level. Keep it to what this pass commits to.
