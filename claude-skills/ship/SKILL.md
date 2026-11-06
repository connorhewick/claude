---
name: ship
description: >
  Take a finished branch through every pre-merge check and open or update its pull request. Use
  when the user says "ship this", "open a PR", "ready for review", "run the pre-PR checks", or
  after an approved walkthrough. Runs the project's checks, a code review and a simplify pass in
  a fresh context, then writes the PR body and marks it ready. Not for committing, reviewing
  someone else's PR (review-pr), or before the walkthrough has happened.
allowed-tools: Bash(git *), Bash(gh pr *), Bash(gh issue *), Bash(gh api *), Read, Write, Grep, Glob, Skill, AskUserQuestion
---

Everything a machine can check is checked before a person reads the PR, and the body says exactly
what was run and what was not.

Invoking this skill authorises pushing the current non-default branch. It never authorises
committing, merging, or touching the default branch.

Every step prints what it found. A red step stops the skill until fixed, and a fix re-runs the
gates from step 2 — a review of a diff that has since changed proves nothing.

## 1. Confirm what is being shipped

Run the state checks in `session-hygiene.md` now, not from memory, plus:

```sh
git branch --show-current                    # never the default branch
git fetch origin <default> --quiet
git log --oneline origin/<default>..HEAD
git diff --stat origin/<default>...HEAD
```

- A commit you don't recognise: `session-hygiene.md` says stop and ask.
- If the branch is behind, **rebase onto the base branch, never merge it in**. Resolve conflicts
  by reading both sides; ask if the file is one someone else is known to be editing.
- If the work came from an issue, read it and keep its number for the body.

## 2. Run the project's checks

Find them in the project's `CLAUDE.md`, README, task runner or CI config. Run the full suite the
project uses and **record the exact counts and the branch tip** — they go in the body verbatim.

**When a suite goes red, run the same checks on the base branch before blaming the diff.** A flaky
suite and a real regression look identical from one run.

Lint and format only what the branch changed; a warning is a failure.

**Then read the diff for what was never meant to ship** — machine checks miss most of it:

- print and debug statements, and logging added to find something since found;
- a focused or skipped test (`.only`, `fdescribe`, `xit`, an ignore attribute): a green suite
  proves nothing;
- commented-out code, and a TODO this branch added without an issue behind it;
- a credential, token or real record in a fixture, test or comment (`security.md`);
- a file with no business in the diff: an editor setting, a lockfile changed for an unrelated
  reason, a scratch file.

## 3. Review outside the context that wrote it

```
/code-review          # correctness bugs and cleanup on the diff
/simplify             # quality-only pass: reuse, simplification, altitude
/security-review      # when security.md says the diff qualifies
```

- These run in a fresh context; don't summarise past them.
- **Act on every finding, or record in the body why it was declined.** A silently dropped finding
  is a defect waiting for review to rediscover.
- If anything changed as a result, **return to step 2**.

## 4. Write the body

This section is the one owner of the PR body template. `CLAUDE.md` points here.

Follow the project's PR template. With none, mirror a recent merged PR's sections. Absent both:

- **Title**: a Conventional Commit line for the whole branch, not the last commit's subject.
- `## Summary` — the problem, the decision, and the one thing a reviewer should look at closely.
- Narrative sections as the change warrants. Skip the ones that would be empty.
- `## Architecture changes` — decisions recorded, rules added or edited, or "none". When a
  published contract was touched, `contracts.md` says what this section must state.
- `## Test plan` — the commands actually run, with observed output, counts and the branch tip,
  and a **Not covered** line for anything no check reaches. "Tests pass" without numbers is not a
  test plan.
- `## Known and accepted` — anything deliberately left, with the reason. Include each review
  finding declined in step 3.
- `Closes #<n>` for each issue the branch finishes, so the merge closes them.
- Any attribution footer the project's `CLAUDE.md` or template requires. None by default.

Write it to a file and pass `--body-file`. Never inline a multi-paragraph body.

## 5. Open or update, then mark ready

```sh
git push -u origin "$(git branch --show-current)"
gh pr create --title "<title>" --body-file <file> --base <default>   # first time
gh pr edit <n> --title "<title>" --body-file <file>                  # every push after
gh pr ready <n>
```

**The body describes the whole branch as it stands, not as it was opened.** After any later
push, regenerate the body and edit the PR.

**Draft is for unfinished work.** Mark the PR ready the moment the branch's own work is done,
even when a downstream PR in a stack is still in progress.

## 6. Say how it is turned off

A merge is not a landing. Before the PR is out of your hands:

- **A change whose failure is someone else's bad day goes behind a flag that defaults off** — a
  new write path, anything touching money, permissions or deletion, anything whose blast radius a
  test can't show. Ramp it deliberately.
- **A flag is temporary or it is architecture.** Record its removal as a task the day it is
  added; a flag nobody deletes is an untested branch forever.
- **Anything a revert doesn't undo states how it is undone**, in `## Known and accepted` — the
  migration's contract step, the flag to flip, the queue to drain. "Roll back the deploy" is not
  a plan once the schema has moved.
- **Watch it land.** Check the thing the change was meant to affect and say what you saw.

## 7. Leave the workspace as you found it

Remove only what this session created — scratch branches, temporary worktrees, test fixtures,
devices or containers. Never delete something by a name you did not create.
