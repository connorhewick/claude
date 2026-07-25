# Coding principles

Optimize for the engineer who reads this code next, not just for making it work — correctness
and clarity both matter.

- Single Responsibility: a class/module/function should have one reason to change. If two
  unrelated stakeholders would each want to change the same unit for different reasons, split it.
- Open/Closed: prefer extending behavior (a new implementation, a new case) over modifying
  already-working, already-tested code in place.
- Liskov Substitution: a subtype must be usable anywhere its base type/protocol is used without
  surprising the caller — no throwing on an inherited method the base type wouldn't throw on, no
  narrowing preconditions, no widening postconditions.
- Interface Segregation: don't force a caller to depend on methods it doesn't use. Split a fat
  interface into role-specific ones rather than making every implementer stub out the rest.
- Dependency Inversion: depend on abstractions, not concrete implementations, at boundaries where
  the concrete thing is likely to vary or needs to be swapped in tests (I/O, external services,
  persistence) — not everywhere reflexively.
- DRY means eliminating duplicate *knowledge*, not duplicate text. Two blocks that look similar
  today but change for different reasons and at different times are not a DRY violation — don't
  force a shared abstraction onto them just because they're similar right now (see the
  premature-abstraction guidance in the base system prompt).
- Names should reveal intent well enough that a reader doesn't need to open the definition to
  guess what something is for. Avoid abbreviations, single-letter identifiers outside a tight
  local scope (loop counters, lambda params), and type-encoded names. This applies especially to
  variables: name a variable for what it holds or represents, not a generic placeholder (`data`,
  `tmp`, `flag2`, `x1`) that tells a reader nothing about its purpose.
- Keep functions small and single-purpose: one function, one level of abstraction. If describing
  what it does needs "and," split it.
- Prefer guard clauses over nested conditionals: handle the exceptional/early-return case first
  and let the main logic run unindented, rather than wrapping it in nested `if`/`else`.
- Avoid magic numbers and string literals scattered through logic — give a value a named constant
  once its meaning isn't obvious from the surrounding context.

## Comments

- A comment describes what the current code does and why, for a reader with no history — not how
  it got here. Don't narrate change history in a comment (referencing past behavior, "changed
  from X", ticket/PR references); that belongs in the commit message or PR description, not
  inline.
- Don't restate what good naming and structure already communicate. A comment earns its place
  only by adding information the code itself doesn't — the non-obvious why, a constraint, a
  workaround for something external.
- Don't bake in specifics that will silently go stale (exact values, current caller names,
  today's architecture) unless that specificity is itself durable. Prefer a comment that stays
  true even as the surrounding code shifts.
- Delete commented-out code instead of leaving it in place — git history is the record of removed
  code, not inline comments.
- Don't write boilerplate docstrings that just restate the function/parameter names with nothing
  the signature doesn't already say. A docstring should add a contract, edge case, or unit that
  isn't otherwise visible.
