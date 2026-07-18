# Global engineering config

Personal, cross-project defaults for Claude Code, installed at `~/.claude/CLAUDE.md` so they
load in every project on this machine. Intentionally stack-agnostic: no project- or
company-specific rules live here — those belong in a project's own `AGENTS.md` / `CLAUDE.md`.

This file is a component from the `connorhewick/claude` repo. To (re)install or update it, run
`./install.sh global-rules` from that repo — it backs up any existing `~/.claude/CLAUDE.md`
first. Edit your own additions below the marked line; a re-install will not silently discard a
file it can't back up.

## Working method (every project)

- Plan-first on non-trivial work (3+ steps or an architectural choice): write a short spec and a
  checklist before editing. If the approach stops working, stop and re-plan rather than pushing on.
- Keep the main context clean by delegating research and parallel investigation to subagents —
  one focused task per subagent.
- Definition of done: a change is done only when the relevant checks/tests pass, a human has
  reviewed and approved it, and the task's stated acceptance criteria are met — none of these
  alone is sufficient. Don't declare something done on partial satisfaction of this list.
- Code walkthrough + interview (human in the loop): before handing a non-trivial change off for
  review or a PR — and before treating it as done — walk the human through it and interview them
  for the decisions only they can make. This is the mechanism for the "a human has reviewed and
  approved" clause above, and the convergence checkpoint when work is fanned out across parallel
  agents. Don't skip it on multi-file, cross-cutting, or hard-to-reverse changes. Run it in three
  steps:
  1. **Walkthrough** — narrate the change in review order: the problem it solves, the key files
     and the path through them, and the decision points or trade-offs taken along the way.
     Reference code as `file:line`. Lead with the shape of the change, not a line-by-line dump.
  2. **Interview** — ask the questions whose answers you couldn't safely assume: choices between
     viable approaches, scope you're unsure is in or out, and anything you inferred rather than
     were told. Use `AskUserQuestion`; record deferred answers as open questions instead of
     guessing.
  3. **Incorporate** — apply the human's answers before converging the change or opening the PR.

  Skip it only for trivial changes (typos, one-line fixes) where there is nothing to decide.

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
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so it always describes the full current state of the branch — every
  change on it — not just what existed when it was opened. A stale PR description is a review
  hazard.
- Don't edit files under a path marked read-only/generated/vendored, if a project declares one
  (e.g. generated lockfiles, vendored dependency dirs, a build output directory).
- In any given project, otherwise follow that project's own stated conventions
  (`AGENTS.md`/`CLAUDE.md`/`.claude/rules/*.md`).

<!-- Add your personal preferences below this line; re-running install.sh global-rules backs up
     the whole file before replacing it, so your additions are recoverable from the .bak copy. -->

## spec first planning

Before making changes for a non-trivial task, produce a short spec and an ordered checklist —
don't start editing files first.

1. Restate the goal in one or two sentences, and list anything ambiguous or undecided as an
   open question rather than silently picking an answer.
2. Produce the plan yourself, grounded in the current project's actual conventions and
   constraints — any stated definition of "done" and version-control/documentation conventions
   in `AGENTS.md`/`CLAUDE.md`, and path-scoped rules in `.claude/rules/*.md` relevant to the paths
   the plan touches. Delegate to a dedicated planning subagent instead, only if the session
   already has one available for this project.
3. Present the resulting checklist to the user before starting implementation. Get open
   questions resolved first.
4. Keep the plan itself stack-agnostic unless the user's request already commits to a
   language/framework/tool.

Do not skip straight to implementation on a multi-step task just because the shape of the
change seems obvious — a wrong early assumption is more expensive to unwind after code exists.

## Documentation conventions

- Write an ADR for any significant or hard-to-reverse architectural decision (new dependency,
  schema change, cross-cutting refactor, choice between competing approaches). Use the
  `write-adr` skill if available; otherwise use a lightweight context/decision/consequences
  template.
- Keep documentation for a stack-agnostic core language/framework-agnostic. Stack-specific
  documentation belongs alongside the stack-specific code, not mixed into shared docs.
- Prefer short descriptive names over bare identifiers when referencing tickets (Jira, etc.) or
  documents (PRDs, ADRs). Use `PROJ-142-oauth-token-refresh` rather than `PROJ-142`, and
  `ADR4-postgres-over-dynamo` rather than `ADR4`. The description makes the reference
  self-explanatory when resuming a session's task later, without needing to re-open the ticket
  or document to recall what it covers.

## SwiftUI

- Always include a working `#Preview` when writing or editing a SwiftUI `View` — the SwiftUI
  equivalent of verifying a UI change in a browser before calling it done.
- Keep the Xcode project's `ENABLE_PREVIEWS` build setting `YES` (the modern Xcode default);
  don't disable it.
