# Global engineering config

Personal, cross-project defaults for Claude Code, installed at `~/.claude/CLAUDE.md` so they
load in every project on this machine. Intentionally stack-agnostic: no project- or
company-specific rules live here — those belong in a project's own `AGENTS.md` / `CLAUDE.md`.

This file is a template shipped by the Claude Code harness. To (re)install or update it, run
`scripts/install-global.sh` from the harness repo — it backs up any existing `~/.claude/CLAUDE.md`
first. Edit your own additions below the harness content; a re-install will not silently discard
a file it can't back up.

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

## When a repo ships the harness

A harness repo has a `.claude/verify` entrypoint plus `.claude/agents/` and `.claude/skills/`.
In those repos:

- Treat `.claude/verify` as the arbiter of "done." A change is done only when the relevant
  verify stages pass, CI is green, a human has approved, and the stated acceptance criteria are
  met — never on partial satisfaction.
- Drive substantial work through the development cycle: frame (`write-prd`) → plan
  (`spec-first-planning`) → investigate (`explorer`) → decide (`write-adr`) → implement →
  review (`reviewer`) → verify (`verifier`) → ship (`prepare-pr`).
- Delegate to the role subagents rather than doing everything inline: `planner`, `explorer`,
  `reviewer`, `verifier`, `doc-writer`. Each is read-only or narrowly scoped by design.
- Respect the project's guardrails and path-scoped rules (`.claude/rules/*.md`, the PreToolUse
  hooks). They are deterministic and fail-closed — don't work around them.

In repos without the harness, apply the working method and version-control defaults above and
otherwise follow that project's own conventions.

<!-- Add your personal preferences below this line; re-running install-global.sh backs up the
     whole file before replacing it, so your additions are recoverable from the .bak copy. -->
