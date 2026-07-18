# doc-writer

**Type:** agent · installs to `~/.claude/agents/doc-writer.md`

Maintains README, ADRs, and changelog-equivalent documentation. Full tool access, scoped by
instruction to docs/README/ADRs only — if a doc update reveals the underlying thing it describes
is wrong, it reports that instead of silently fixing the code.

Delegate to it (`Agent` tool, `subagent_type: doc-writer`) after a significant decision or
change that needs recording, or when docs have drifted from the code.
