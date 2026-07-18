# documentation-rules

**Type:** rule · installs to `~/.claude/rules/documentation-rules.md`

Personal documentation conventions: when to write an ADR, keeping shared docs stack-agnostic,
and using descriptive ticket/document references (`PROJ-142-oauth-token-refresh`, not
`PROJ-142`). Loads unconditionally (no `paths` frontmatter) since these apply whenever writing
documentation, regardless of which files changed — there's no file glob that reliably captures
"writing docs," unlike a language-scoped rule.

Split out of [`global-rules`](../global-rules), which had this content duplicated across two
sections (`## Documentation conventions` and `## Documentation`).
