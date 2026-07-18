# doc-sync

**Type:** skill · installs to `~/.claude/skills/doc-sync/`

Audits a project's documentation (README, `docs/**`, or an explicit path list) against its code
over a git diff range, and either reports drift (`report` mode) or fixes it (`fix` mode, the
default). Orchestrates the `explorer` → `planner` → `doc-writer` → `reviewer` agents in
sequence rather than doing the work inline.

**Dependency:** requires the [`explorer`](../explorer), [`planner`](../planner),
[`doc-writer`](../doc-writer), and [`reviewer`](../reviewer) agents to also be installed.

Run explicitly with `/doc-sync [mode] [range] [paths...]`, or auto-invoked for requests like
"are the docs stale" or "sync the docs".
