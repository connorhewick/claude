---
paths:
  - "docs/**"
  - "**/*.md"
---

# Documentation conventions

- Write an ADR for any significant or hard-to-reverse architectural decision (new dependency,
  schema change, cross-cutting refactor, choice between competing approaches). Use the
  `write-adr` skill if available; otherwise use a lightweight context/decision/consequences
  template.
- Keep documentation for a stack-agnostic core language/framework-agnostic. Stack-specific
  documentation belongs alongside the stack-specific code, not mixed into shared docs.
