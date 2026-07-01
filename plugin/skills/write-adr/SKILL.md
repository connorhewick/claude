---
name: write-adr
description: Write an Architecture Decision Record for a significant or hard-to-reverse decision. Use when a new dependency, schema change, cross-cutting refactor, or a choice between competing architectural approaches has just been made.
argument-hint: [short-title]
---

Record the decision at `docs/adr/NNNN-short-title.md`, where `NNNN` is the next unused
four-digit number in `docs/adr/` (start at `0001` if the directory doesn't exist yet). Use this
template — keep it lightweight, not a long design document:

```markdown
# NNNN. <Short title>

Date: <YYYY-MM-DD>

## Status

Accepted

## Context

<What situation/constraint/problem made a decision necessary. Facts, not justification.>

## Decision

<The decision, stated plainly, in one or two sentences.>

## Consequences

<What becomes easier or harder as a result. Include real tradeoffs, not just upsides.>
```

Rules:
- One ADR per decision. Don't retroactively edit a past ADR to reflect a later change — write
  a new one and reference the superseded one in its Context.
- Keep it factual and dated; don't pad it to look thorough.
- Stay stack-agnostic in the harness core's own ADRs; a project adopting this harness may
  write stack-specific ADRs in its own `docs/adr/`, which is fine — that's not this file's
  concern.
- If a decision is already captured in `DECISIONS.md` (a Phase interview answer), an ADR is
  only warranted when the decision is significant/hard-to-reverse enough to need the fuller
  Context/Consequences treatment — not every recorded decision needs one.
