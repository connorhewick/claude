# Engineering conventions

## Definition of done

A change is done only when **all** of the following hold:
- Any checks this repo defines for itself (shellcheck, a dry-run install/uninstall) pass.
- CI is green.
- A human has reviewed and approved the change.
- The task's stated acceptance criteria are met.

None of these alone is sufficient. Do not declare a task complete on partial satisfaction of
this list.

## Version control

- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, …) for
  every commit message.
- When committing work that spans more than one distinct concern, split it into one logical,
  atomic commit per concern (the `split-commits` skill / `/split-commits`) rather than a single
  mixed commit. Always present the commit plan and get approval before committing — never
  auto-commit.
- Every pull request body must follow the project's PR template.
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so the title and body always describe the full current state of the
  branch — every change on it — not just what existed when the PR was opened. A stale PR
  description is a review hazard.
- Never push directly to the default branch. All changes go through a branch and a pull
  request.

## Documentation

- Write an ADR for any significant or hard-to-reverse architectural decision. Use the
  `write-adr` skill if available; otherwise use a lightweight template capturing context,
  decision, and consequences.
- Prefer short descriptive names over bare identifiers when referencing tickets (Jira, etc.)
  or documents (PRDs, ADRs). Use `PROJ-142-oauth-token-refresh` rather than `PROJ-142`, and
  `ADR4-postgres-over-dynamo` rather than `ADR4`. The description makes the reference
  self-explanatory when resuming a session's task later, without needing to re-open the
  ticket or document to recall what it covers.

## Absolute prohibitions

- Never push to the default branch.
- Never edit files under a path marked read-only/generated/vendored, if this repo declares one
  (e.g. its own `.claude/rules/*.md`).

## Claude Code

This repo is a composable library of Claude Code components (skills, agents, rules) — see
`README.md` for the full catalog and `install.sh`/`uninstall.sh` usage. Each component lives in
its own top-level directory with its source file and a `README.md`; there is no project-level
`.claude/agents`/`.claude/skills`/`.claude/rules` in this repo itself; developing the components
doesn't require having them installed.

## Feature branches and parallel work

Start every new feature on its own feature branch (naming and the never-push-to-default rule
are in the Version control section above) — never build a new feature directly on the branch
you happen to be on. When more than one feature is active at once, give each its own git
worktree via `EnterWorktree` (one worktree per in-flight feature) rather than stashing or
switching branches inside a single working tree, so uncommitted work on one feature never
blocks or bleeds into another. Use `ExitWorktree` — `keep` to preserve a branch you'll return
to, `remove` once it's merged or abandoned — to move between them.

## Code walkthrough + interview (human in the loop)

Before handing a non-trivial change off for review or a PR — and before treating it as done —
walk the human through it and interview them for the decisions only they can make. This is the
mechanism for the "a human has reviewed and approved" clause of the definition of done above,
and the convergence checkpoint when work is fanned out across parallel agents. Don't skip it on
multi-file, cross-cutting, or hard-to-reverse changes.

Run it in three steps:

1. **Walkthrough** — narrate the change in review order: the problem it solves, the key files
   and the path through them, and the decision points or trade-offs taken along the way.
   Reference code as `file:line`. Lead with the shape of the change, not a line-by-line dump.
2. **Interview** — ask the questions whose answers you couldn't safely assume: choices between
   viable approaches, scope you're unsure is in or out, and anything you inferred rather than
   were told. Use `AskUserQuestion`; record deferred answers as open questions instead of
   guessing.
3. **Incorporate** — apply the human's answers before converging the change or opening the PR.

Skip it only for trivial changes (typos, one-line fixes) where there is nothing to decide.

## Pending PR walkthroughs

An auto-review workflow (`.github/workflows/claude-pr-review.yml`) queues advisory walkthrough
plans on the `claude-memory` branch whenever @connorhewick is tagged, assigned, or requested as
a reviewer on a PR. When ready, a live Claude Code session picks up a plan, runs the
walkthrough+interview above, and only then posts consolidated advisory comments to the PR. This
is this repo's own copy of the same content shipped as the installable `walkthroughs` rule
component — kept here by hand (not generated) so this repo keeps working on itself.

### Storage layout (on the `claude-memory` branch)

```
WALKTHROUGHS_TODO.md          # top-level list; check this first
walkthroughs/README.md        # format spec for plan files
walkthroughs/PR-<n>-<slug>.md # one plan per pending walkthrough
completed/PR-<n>-<slug>.md    # archived after the human finishes a walkthrough
```

The `claude-memory` branch is orphaned from `main` — it never merges anywhere. Do not attempt to
rebase, merge, or open a PR against it.

### When to consult this

- The user asks "what walkthroughs are pending?", "any PRs to review?", "walk me through PR-N",
  or similar.
- The user tags you into a PR review session.
- On session start, if there is signal that walkthrough work is expected (a `claude-memory`
  remote is present and the user's recent activity mentions PR review).

Do NOT poll or fetch `claude-memory` on every session — only when the user's request is about
PR review or walkthroughs.

### Procedure — running a queued walkthrough

1. **Fetch the memory branch into a worktree** so it doesn't disturb the current working tree:
   ```
   git fetch origin claude-memory
   git worktree add /tmp/claude-memory origin/claude-memory
   ```
2. **Read `/tmp/claude-memory/WALKTHROUGHS_TODO.md`** and pick the entry the user is asking
   about (or list the pending entries if they haven't chosen).
3. **Read the plan file** at `/tmp/claude-memory/walkthroughs/PR-<n>-<slug>.md`. The plan
   contains: summary, review order with `file:line` refs, decision points, and DRAFT advisory
   findings.
4. **Walk the human through it** in review order per the "Code walkthrough + interview"
   convention above. Reference code as `file:line`. Lead with the shape of the change.
5. **Interview** using `AskUserQuestion` for every decision point in the plan. Record deferred
   answers as open questions, do not guess.
6. **Consolidate findings** — apply the human's answers to the DRAFT findings. Drop findings the
   human dismissed. Sharpen findings they refined.
7. **Confirm before posting** — show the human the final comment set and get explicit approval
   to post. This is a "risky action visible to others" per the Claude Code
   executing-actions-with-care rules.
8. **Post to the PR** — use the GitHub MCP tools (`mcp__github__pull_request_review_write` with
   method `create` to open a pending review, `mcp__github__add_comment_to_pending_review` for
   each line-anchored finding, then `pull_request_review_write` with method `submit_pending` and
   event `COMMENT` — advisory, never `REQUEST_CHANGES` or `APPROVE` unless the human asks for
   it).
9. **Archive the plan**:
   ```
   cd /tmp/claude-memory
   git mv walkthroughs/PR-<n>-<slug>.md completed/PR-<n>-<slug>.md
   ```
   Update `WALKTHROUGHS_TODO.md`: move the entry from "Pending" to "Recently completed" with
   today's date.
   ```
   git -c user.name="..." -c user.email="..." commit -m \
       "chore(walkthrough): complete PR-<n>"
   git push origin HEAD:claude-memory
   ```
10. **Clean up the worktree**: `git worktree remove /tmp/claude-memory`.

### Guardrails

- **Never** modify a walkthrough plan file to make it "look better" without the human's input —
  the plan is CI's draft; edits to it must come from the interview.
- **Never** post to a PR without the human's explicit approval on the final comment set.
  "Advisory" means the human's voice, not the auto-review's raw output.
- **Never** open a PR from `claude-memory`. It is an orphan branch by design.

## SwiftUI previews

This repo has no SwiftUI code, so this rule is dormant here — it exists for consistency with
`~/.claude/CLAUDE.md`. Wherever SwiftUI code is touched: always include a working `#Preview` for
every `View` you write or edit — the SwiftUI equivalent of verifying a UI change in a browser
before calling it done. Keep the Xcode project's `ENABLE_PREVIEWS` build setting `YES` (the
modern Xcode default); don't disable it.
