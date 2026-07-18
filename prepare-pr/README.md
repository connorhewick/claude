# prepare-pr

**Type:** skill · installs to `~/.claude/skills/prepare-pr/`

Reviews the full diff and commit range against the target branch and drafts a PR title/body —
Conventional Commit title, the repo's PR template if it has one, otherwise a Summary/Test-plan
structure. Never pushes or opens the PR itself; hands the draft back for you to act on.

Manual only — run `/prepare-pr` right before opening a pull request.
