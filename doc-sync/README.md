# doc-sync

**Type:** skill · installs to `~/.claude/skills/doc-sync/`

Audits a project's documentation (README, `docs/**`, or an explicit path list) against its code
over a git diff range, and either reports drift (`report` mode) or fixes it (`fix` mode, the
default). Orchestrates the `explorer` → `planner` → `doc-writer` → `reviewer` roles in
sequence rather than doing the work inline.

Those four roles are bundled directly in this directory (`explorer-agent.md`,
`planner-agent.md`, `doc-writer-agent.md`, `reviewer-agent.md`) — not separately installed
components. `SKILL.md` reads each one's body and dispatches it via the `Task` tool at runtime.

Run explicitly with `/doc-sync [mode] [range] [paths...]`, or auto-invoked for requests like
"are the docs stale" or "sync the docs".
