---
name: write-adr
description: Write an Architecture Decision Record for a significant or hard-to-reverse decision — whether it's already made or still open. Use when a new dependency, schema change, cross-cutting refactor, or a choice between competing architectural approaches has just been made, or when the user wants help deciding between competing approaches before one gets recorded. Do NOT trigger for routine or easily-reversible choices, a decision already recorded elsewhere, product/requirements scoping (that's write-prd), or a full feature/API/data-model design spanning multiple sections (that's write-tdd).
argument-hint: >
  [short-title]
---

## 1. Route: open decision, or already made?

Before drafting anything, work out which case this is. If it isn't clear from how write-adr was
invoked, ask the user directly.

**If the decision is still open** (multiple options genuinely on the table), run a trade-off
analysis before drafting:

1. Clarify evaluation criteria with the user — what matters here (e.g. performance, operational
   simplicity, team familiarity, cost)? Infer from context already stated instead of asking, when
   that's already clear.
2. Make sure at least two alternatives are on the table. If the user has supplied fewer than
   two, propose common alternatives for this kind of decision from `references/decision-domains.md`
   and confirm them with the user before proceeding — don't invent alternatives that aren't in
   that reference and weren't raised by the user.
3. Compare the alternatives in a criteria-matrix table: criteria as rows, options as columns,
   the per-criterion winner marked.
4. Recommend one option and state why, tied to the criteria. Explicitly call out any criterion
   where a different priority would favor the other option instead — don't present the
   recommendation as universally correct.

Once the user confirms a direction, carry the analysis's outcome (criteria, alternatives,
rejection reasons, recommendation) into the draft below.

**If the decision is already made**, ask exactly one probing question before drafting: *"What
alternatives did you consider, and what made you choose this?"* Use the answer to populate
Context/Decision/Alternatives/Consequences below — don't draft until you have it.

## 2. Draft the ADR

Record the decision at `docs/adr/NNNN-short-title.md`, where `NNNN` is the next unused
four-digit number in `docs/adr/` (start at `0001` if the directory doesn't exist yet). Use this
template — keep it lightweight, not a long design document:

```markdown
# NNNN. <Short title>

Date: <YYYY-MM-DD>

## Status

<Proposed — unless the user has explicitly confirmed the decision is final, in which case Accepted.>

## Context

<What situation/constraint/problem made a decision necessary. Facts, not justification. Name the
forces pulling in different directions. Don't mention or foreshadow the chosen option here.>

## Decision

<Stated plainly and unambiguously, in the first sentence. Followed by the rationale, tied back to
the forces named in Context.>

## Diagram

<Plain-text ASCII box diagram of the chosen design, fenced as a code block. See the rule below.>

## Alternatives Considered

<At least two alternatives, each with a specific, concrete reason it was rejected — not a
vague "didn't fit.">

## Consequences

<What becomes easier or harder as a result. Include at least one real trade-off/negative, not
just upsides. Include revisit triggers: what would make this decision worth re-evaluating.>

## Related Decisions

<Links to prior ADRs that constrain or are affected by this one. "None" if there aren't any.>
```

### Diagram rule (always included, never assumed)

Every ADR includes the ASCII diagram — this is unconditional, not gated on how complex the
decision is. But never diagram from assumption: every box and arrow must correspond either to
real code you've actually read, or to a well-defined proposal actually discussed with the user.
If you haven't read the relevant code or walked through the shape with the user yet, do that
first rather than sketching a plausible-looking guess.

## 3. Self-check before delivering

Before showing the finished ADR to the user, check it against every item below and fix anything
that fails:

- [ ] Title is an imperative phrase naming the decision, not the problem
- [ ] Context does not mention or foreshadow the chosen option
- [ ] Context names the forces pulling in different directions
- [ ] Decision is stated in the first sentence, unambiguously
- [ ] Rationale ties back to the forces described in Context
- [ ] Revisit triggers are included (when to re-evaluate this decision)
- [ ] At least two alternatives with specific, concrete rejection reasons
- [ ] Consequences include at least one negative/trade-off item
- [ ] Status defaults to `Proposed` unless the user has explicitly confirmed the decision is
      final (in which case `Accepted`)
- [ ] Date is present and correct
- [ ] No placeholder text remains unless intentional
- [ ] Related Decisions links prior ADRs that constrain or are affected by this one

## Rules

- One ADR per decision. Don't retroactively edit a past ADR to reflect a later change — write
  a new one and reference the superseded one in its Context. The ADR set is an append-only
  record of what was decided and why *at the time*; rewriting a past one erases the context a
  later reader needs to understand how the current state came to be.
- Keep it factual and dated; don't pad it to look thorough.
- If a decision is already captured elsewhere (e.g. a `DECISIONS.md` log), an ADR is only
  warranted when the decision is significant/hard-to-reverse enough to need the fuller
  Context/Consequences treatment — not every recorded decision needs one.
- For common decision domains (datastore, message queue, auth, etc.) to propose as alternatives
  when the user hasn't supplied at least two, see `references/decision-domains.md`.
