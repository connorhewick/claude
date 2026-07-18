# walkthroughs

**Type:** rule · installs to `~/.claude/rules/walkthroughs.md`

Teaches a session how to pick up and run a queued PR walkthrough: fetch the orphaned
`claude-memory` branch into a worktree, read the pending plan, walk the human through it
(`file:line` review order) and interview them for decisions, consolidate findings, get explicit
approval, then post an advisory review to the PR via the GitHub MCP tools.

**Dependency:** this rule assumes the companion automation exists in the project it's installed
into — a `claude-memory` orphan branch (seeded by something like `scripts/init-claude-memory.sh`)
and a CI workflow that queues walkthrough plans there (e.g. on being tagged as a PR reviewer).
Without that automation the rule has nothing to act on. It also assumes the "Code walkthrough +
interview" convention is defined in the project's own `AGENTS.md`.
