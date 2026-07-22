# Documentation

- Write an ADR for any significant or hard-to-reverse architectural decision (new dependency,
  schema change, cross-cutting refactor, choice between competing approaches). Use the
  `write-adr` skill if available; otherwise use a lightweight context/decision/consequences
  template.
- Keep documentation for a stack-agnostic core language/framework-agnostic. Stack-specific
  documentation belongs alongside the stack-specific code, not mixed into shared docs.
- Prefer short descriptive names over bare identifiers when referencing tickets (Jira, etc.) or
  documents (PRDs, ADRs). Use `PROJ-142-oauth-token-refresh` rather than `PROJ-142`, and
  `ADR4-postgres-over-dynamo` rather than `ADR4`. The description makes the reference
  self-explanatory when resuming a session's task later, without needing to re-open the ticket
  or document to recall what it covers.
- Every generated doc file gets a Table of Contents after the title, with anchor links matching
  each heading (lowercase, spaces → hyphens, punctuation stripped). Keep it current when
  sections change.
