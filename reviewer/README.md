# reviewer

**Type:** agent · installs to `~/.claude/agents/reviewer.md`

Read-only review of a diff or change set against the project's stated conventions and its own
definition of "done" (if any is documented in `AGENTS.md`/`CLAUDE.md`). Reports concrete,
falsifiable findings — file:line, what's wrong, why — never edits source.

Delegate to it (`Agent` tool, `subagent_type: reviewer`) before declaring a change complete, or
for a second opinion on a diff.
