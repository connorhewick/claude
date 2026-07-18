# explorer

**Type:** agent · installs to `~/.claude/agents/explorer.md`

Read-only codebase investigation in an isolated context — finds where something is defined, how
a convention is applied, or surveys an area before planning changes. Never edits; reports
findings only (file paths, line numbers, quoted context).

Delegate to it (`Agent` tool, `subagent_type: explorer`) for open-ended searches across a
codebase.
