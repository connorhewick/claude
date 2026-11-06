<!--
  Portable engineering defaults. Stack-agnostic: nothing here names a language or framework.
  The source is claude-rules/global-rules.md in the claude-config bundle, installed as
  ~/.claude/CLAUDE.md. README.md there has the install steps, the load budget and the ownership
  map; install.sh applies them and lists every command this bundle names.
  HTML comments are stripped before this file enters context, so this note is free.
-->

# Engineering defaults

A project's own `CLAUDE.md`, `AGENTS.md` or `.claude/rules/` beats everything below.

## How I work

- **Plan first on non-trivial work** (three or more steps, or an architectural choice): restate
  the goal in two sentences, list each ambiguity as an open question instead of picking silently,
  present an ordered checklist, and resolve the questions before the first edit.
- **Skip the plan when no decision is mine to make** — an obvious fix, a lint cleanup, a rename,
  however many edits.
- **Read the code around the change first.** Match its naming, error reporting, module shape and
  test style, or say why this change should break them: a better pattern in one file is a third
  convention.
- **If the approach stops working, stop and re-plan.**
- **Diagnose a failure before fixing it.** A fix with no named cause is not a fix.
  `code.md` §Debugging has the procedure.
- **Non-trivial work starts in its own worktree**, off a freshly fetched default branch, before
  the first edit. A mechanical fix that skips the plan may skip this too.
- **Read the tree before touching it.** Uncommitted changes you didn't make, or a branch you
  didn't create, are someone else's work: don't revert, switch away from, or build on them.
  Checks: `session-hygiene.md`.
- **Never `git stash`** — the stack is shared by every worktree. Set work aside as a WIP commit
  on your own branch, the one commit permitted without being asked.

## Talking to me

- **Terse.** Length matches the task, not the effort spent. No preamble, no restating.
- Show code when the code is the answer, describe it when the shape is. Tables
  for anything enumerable, prose for judgement.
- **Ground every question in evidence.** Run the greps and counts first; put real numbers and
  samples in the options.
- **Offer categories I didn't name** — failure modes I hadn't thought of.
- **"I don't know what to answer" means the question was badly cut.** Don't re-ask: explain why
  it is hard, split it into the distinctions that differ, and recommend one.
- **Write for someone who wasn't here.** Commits, PR bodies, issue comments and rule files are
  all a teammate sees; reasoning left in chat is lost.

## Done and shipped

- **In the session, done means the checks pass and the stated acceptance criteria are met.**
  Neither alone is enough.
- **Outside it, a change ships when a human has reviewed and approved it.** That gate is mine:
  never treat it as met, never write it into a goal.
- **State the in-session condition as a goal** (`/goal <condition>`) on non-trivial work.
- **Verify the way the stack allows** — run it, render it, call it; `/run` finds the project's
  launch path. "It compiles" is not verification.
- **Run `walkthrough` before calling non-trivial work done**, unless there is nothing to decide.
- **Nothing opens a PR before it has been reviewed outside the context that wrote it.**
  `review-pr` reviews someone else's.
- **Finish the whole task.** If part is blocked, finish the rest and say what was left and why.
  Scaling the work down is my call.

## Version control

- **Conventional Commits.**
- **Never commit or push unless asked.** Cutting an `integration/<slug>` branch per `session-hygiene.md` pushes it
  too; the WIP commit is the remaining exception. **Never push to the default branch.**
- **Branch `<type>/<slug>`**, issue number first when there is one
  (`fix/issue-53-device-logs-auto-invoke`). Work from an issue follows the `issues` skill.
- **One concern per commit.** When the tree spans several, present the split for approval before
  committing anything.
- **Never rewrite pushed history** or resolve a divergence by force. Rebase onto the base branch
  rather than merging it in, after confirming whose commits are whose.
- **Before a wide refactor or rename, check open PRs for overlapping paths** and say so in the PR
  body. Don't push WIP to a shared branch. Respect CODEOWNERS.
- **A refactor changes no behaviour and no test**, one mechanical step per commit, never in the
  feature's PR. If a test had to change, it wasn't one — say what changed.
- **Don't edit a generated, vendored or read-only path** (lockfile, vendored tree, build output).
  Change the source and regenerate.
- After a PR merges, delete the branch, return to the default branch and pull.

## Decisions

- **Record an architectural decision as a rule that loads itself, not as a document** — a
  document binds only a session that chooses to read it. Form, scoping and reversal:
  `rules-authoring.md`.
- Record when a change **adds a dependency, changes a schema, cuts across layers, or picks
  between competing approaches** and the losing option was plausible.
- **Justify a new dependency**: the alternatives, including the standard library and what the
  project has, and why this one wins. **Upgrading one**: read its changelog for the range and
  state in the PR what could reach this code.

## Generated documents

A generated document with four or more sections gets a table of contents after the title: anchor
links matching each heading (lowercase, hyphens for spaces, punctuation stripped), kept current.

## Delegating to subagents

- **Delegate** read-only investigation, independent parallel areas, and multi-step work whose
  exploration detail needn't survive in the main context.
- **Keep it inline** when the task must interview me, when its context is cheaper to reuse than
  re-derive, or when it is one trivial step.
- **Dispatch without asking, but disclose** in one line: what went out, why, and which tier.
  How to delegate is `session-hygiene.md` §Subagents and fan-out.

## Claude Code itself

- **Your knowledge of Claude Code lags the installed version.** When a capability claim matters,
  verify in order: `claude --version` and `claude --help`, the `CHANGELOG.md` in
  `anthropics/claude-code`, then `https://code.claude.com/docs/`. Otherwise call it unverified.
