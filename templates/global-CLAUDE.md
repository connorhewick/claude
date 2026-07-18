# Global engineering config

Personal, cross-project defaults for Claude Code, installed at `~/.claude/CLAUDE.md` so they
load in every project on this machine. Intentionally stack-agnostic: no project- or
company-specific rules live here — those belong in a project's own `AGENTS.md` / `CLAUDE.md`.

This file is a template from the `connorhewick/claude` component repo. To (re)install or update
it, run `scripts/install-global.sh` from that repo — it backs up any existing
`~/.claude/CLAUDE.md` first. Edit your own additions below the marked line; a re-install will
not silently discard a file it can't back up.

## Working method (every project)

- Plan-first on non-trivial work (3+ steps or an architectural choice): write a short spec and a
  checklist before editing. If the approach stops working, stop and re-plan rather than pushing on.
- Keep the main context clean by delegating research and parallel investigation to subagents —
  one focused task per subagent.
- Prove changes work before calling them done: run the relevant tests/checks and show the
  result, don't assert success.
- Before a PR or handoff on a non-trivial change, walk the human through it and interview them
  for the decisions only they can make — approach trade-offs, scope you're unsure is in or out,
  and anything you inferred rather than were told.

## Version control

- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) on every
  commit. Never commit or push unless asked.
- When staged changes span more than one distinct concern or feature, split them into separate,
  logical, atomic commits rather than one mixed commit — present the split as a plan and get
  approval before committing.
- Start new feature work on its own feature branch, never directly on the branch you happen to
  be on. When more than one feature is active at once, give each its own git worktree
  (`EnterWorktree`/`ExitWorktree`) instead of stashing or switching branches in a single working
  tree, so uncommitted work on one feature never blocks or bleeds into another.
- Never push to a repo's default branch. Branch first, then open a pull request.

## Installed components

Skills, agents, and rules installed from `connorhewick/claude` (via that repo's `install.sh`)
apply globally, across every project — there's no per-repo detection needed. When the relevant
ones are installed, drive substantial work through: frame (`write-prd`) → plan
(`spec-first-planning`) → investigate (`explorer`) → decide (`write-adr`) → implement → review
(`reviewer`) → ship (`prepare-pr`). Delegate to the role subagents (`planner`, `explorer`,
`reviewer`, `doc-writer`) rather than doing everything inline — each is read-only or narrowly
scoped by design.

In any given project, otherwise follow that project's own stated conventions
(`AGENTS.md`/`CLAUDE.md`/`.claude/rules/*.md`).

<!-- Add your personal preferences below this line; re-running install-global.sh backs up the
     whole file before replacing it, so your additions are recoverable from the .bak copy. -->
