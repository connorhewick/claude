---
paths:
  - "docs/**"
  - "**/*.md"
---

# Documentation conventions

- Write an ADR for any significant or hard-to-reverse architectural decision (new dependency,
  schema change, cross-cutting refactor, choice between competing approaches). Use the
  `adr-writer` skill if available; otherwise use the Write-ADR procedure/template
  established in `.claude/skills/` (Phase 7).
- Keep docs stack-agnostic in the harness core. Stack-specific documentation belongs to the
  future specialization task, not here.
