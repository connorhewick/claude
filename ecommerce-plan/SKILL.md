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

Treat `$ARGUMENTS` as the business name or starting context.

## Evidence rule (applies throughout)

Every number, capability, or fact in the plan cites its source: the user, a file or export they
provided, or the site audit. Anything without a source is written as `unknown`, with how to
measure it. Never invent metrics, prices, reviews, or what a system can do.

## 1. Classify

Establish the **profile card** before planning anything:

1. Infer what you can from `$ARGUMENTS` and the conversation so far.
2. Ask everything still missing in **one batch** of questions, not one at a time.
3. Present the card and wait for the user to confirm or correct it before starting §3.

Card fields:

1. **Size** — micro / small / medium, by whichever is the stronger constraint: headcount, monthly
   orders, or number of products. Thresholds and defaults: `references/profiles.md`.
2. **Online level** — L0 no presence → L4 optimised. Definitions and capability checklist:
   `references/online-ladder.md`.
3. **Data-entry maturity, per entity** (products, stock, prices, customers, orders) — manual →
   files → semi-structured → API → governed. Strategies: `references/intake-adapters.md`.
4. **Offer type** — physical goods (fulfilment promise), services/bookings (availability,
   deposits, rescheduling), or digital goods/subscriptions (entitlement delivery, recurring
   billing).

Write the card at the top of the plan, e.g. `Small × L1 × catalog: files, stock: manual`.
Different entities legitimately sit at different maturity levels.

## 2. Architecture stance

**Principles (every profile, bought or built):**

- Central entity is the **sellable offer** (item, price, availability, promise, content/SEO).
- **Publish-readiness gate**: incomplete offers stay unpublished and land in a fix queue.
- Channels are outbound adapters on one offer model. Source of truth is declared per entity.
- Each context gets a **build / buy / defer** decision from the size profile, and stays
  swappable behind its interface.

**Layering (only for contexts the build/buy/defer table marks build).** For bought contexts the
platform supplies this; the plan records which product covers each context instead.

```
Channels      own storefront · marketplaces · feeds · B2B/quote form
Experience    storefront API: catalog, search, cart, checkout, account, order status
Commerce      Offer · Cart/Checkout · Orders · Payments · Fulfilment promise
Repository    one repo per aggregate
Intake        adapters → canonical schemas → validation → quarantine (varies per business)
Platform      structured logging with correlation + batch IDs, analytics events,
              feature flags, jobs/outbox, migrations
```

## 3. Run the loop (depth per size in `references/profiles.md`)

Funnel: **Discover → Evaluate → Buy → Receive → Return/Repeat.** Target the weakest stage.

Phases 1–4 are **carried out now**, from evidence. Phases 5–7 are **planned, not executed**:
each gets tasks, an owner, an exit gate, and a rollback.

Carry out now:

1. **Baseline** — funnel and operations numbers (templates: `references/templates.md`).
2. **Find the leak** — biggest drop-off or cost in the funnel. At L1 or above, audit the
   existing site with `references/site-audit.md`. At L0, walk through how a customer buys today
   (messages, phone, in person).
3. **Supply-readiness audit** — can the business reliably supply a complete, correct offer?
   Produce the source-of-truth matrix.
4. **Design** — channel/platform choice, canonical offer, intake mapping, checkout and promise
   rules, build/buy/defer table. Record significant decisions via `write-adr` rather than
   inline.

Plan for later:

5. **Build behind a flag** — smallest change that moves the metric.
6. **Verify as a customer** — browse, buy, pay, ship, refund, plus failure cases.
7. **Release & measure** — controlled rollout; compare with baseline; retire the old path.

Prioritise by hours saved and errors removed for micro/small; by risk-adjusted revenue and
scale for medium. Don't impose structure the business can't sustain: a micro seller maintaining
stock in a sheet gets a validated upload and a clear error report, not a mandatory API.

## 4. Requirements the solution must meet (every size)

For each requirement, the plan states how it is met: **verify** for bought contexts (confirm
the platform does it, and how), **implement** for built ones.

- Money in integer minor units or exact decimals (never floats), with explicit currency.
- Checkout, imports, and webhooks are idempotent; re-uploading yesterday's file is harmless.
- Stock can't oversell: decrements are atomic, and the published promise never exceeds reality.
- Payment status follows the provider's confirmation; webhooks are reconciled, not trusted.
- Every record keeps provenance (source, batch, timestamp); every rejected row gets a
  human-readable fix path.
- No card data in the business's own scope — hosted fields or tokens.
- Every release has a documented rollback.

## 5. Output

If the working directory is the business's own project, write the plan to
`docs/ecommerce-plan/NNNN-<business>-<slug>.md`, where `NNNN` is the next unused four-digit
number in that directory (start at `0001`); it doubles as the pass number. Otherwise, ask the
user where to save it.

After the title, add a table of contents with anchor links to each heading. Sections:

- profile card
- funnel baseline, with sources
- selected target and rationale
- site-audit findings (if run)
- supply-readiness findings and source-of-truth matrix
- build/buy/defer table
- requirements table (verify or implement, and how)
- phases 5–7: tasks, owner, exit gate, rollback per phase
- risks
- the metric that defines this pass as done
- open questions, including every `unknown`

End with the **next-pass trigger**: what result moves the business to the next rung or next
entity maturity level. Keep it to what this pass commits to.
