# git-rules

**Type:** rule · installs to `~/.claude/rules/git-rules.md`

Personal git/version-control conventions: commit message format, atomic commits, feature
branches and worktrees, default-branch protection, and PR hygiene. Loads unconditionally (no
`paths` frontmatter) since these apply whenever you're committing or opening a PR, regardless of
which files changed — unlike a language-scoped rule, there's no file glob to gate it on.

Split out of [`global-rules`](../global-rules) so version-control conventions can be
installed/updated on their own, rather than bundled into the single flat `~/.claude/CLAUDE.md`.
This is this repo's first `rule`-type component — see the "Choosing a component type" section of
`CLAUDE.md` for when a scoped `rule` fits versus `global-rules`.
