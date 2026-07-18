# write-adr

**Type:** skill · installs to `~/.claude/skills/write-adr/`

Writes a lightweight Architecture Decision Record (`docs/adr/NNNN-short-title.md`) — context,
decision, consequences — for a significant or hard-to-reverse decision. One ADR per decision;
past ones are never rewritten, only superseded by a new one that references them.

Run explicitly with `/write-adr [short-title]`, or auto-invoked right after a decision like this
gets made (new dependency, schema change, cross-cutting refactor).
