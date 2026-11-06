---
name: review-pr
description: >
  Review someone else's pull request — a branch this session did not write — and report
  findings at a defined severity bar. Use when the user says "review PR #n", "review this
  branch", "what do you think of <person>'s PR", or asks for a review of work that is not the
  current diff. Not for this session's own branch (ship). Never approves or merges; it produces a
  verdict.
allowed-tools: Bash(git *), Bash(gh pr *), Bash(gh api *), Read, Grep, Glob, AskUserQuestion
---

The author has context you don't, and a wrong finding costs their time.

## The severity bar

Three levels, and every comment declares which it is:

- **Blocking** — correctness, data loss, a security hole, a broken contract, or a change that
  can't be reversed once merged. Nothing else blocks.
- **Nit** — style, naming, structure you'd have done differently. Say "nit:"; the author may
  decline it without discussion.
- **Question** — something you couldn't verify from the diff. Ask it as a question.

**Never block on what a formatter or linter should catch.**

## What a finding must carry

- **A concrete failure scenario**: specific inputs or state, and the wrong output or crash that
  results. Without one it is a question.
- **Verification before reporting.** Re-read the surrounding code and check the claim holds in
  this codebase, not in general. Say so when you could not confirm it.
- **One comment per problem**, at the line that owns it. If the design is wrong, say why once, at
  the top.

## Scope and tone

- **Review the change that was made, not the change you would have made.** An alternative
  approach is a blocking finding only when the one chosen is actually wrong.
- **A diff you cannot hold in your head is itself a finding.** Say it once, at the top, with the
  seam it should be split along — not as a nit, and not by reviewing line by line anyway. A
  shallow review is worse than an honest refusal.
- **Say what you did not review** — a skimmed file, a path you couldn't run, generated output
  taken on trust. Silence reads as coverage.
- **Praise** what is genuinely well done, in a line.
- End with an explicit verdict: approve, or request changes with the blocking items named.

## Procedure

1. `gh pr view <n>` and `gh pr diff <n>`. Read the description and every comment first — the
   acceptance criteria and prior review rounds are there.
2. Check the diff against `contracts.md` if it touches a published contract, and against
   `security.md` if it touches the trust boundary.
3. `/code-review <pr#|branch>` for a fresh-context pass. Its output is input, not the review;
   every finding still has to clear the bar above.
4. Report findings to me first. Post inline with `--comment` only when I say so.

## Reviewing a change written by a model

Same bar; "a model wrote it" is not a defect. Review in a fresh context, not the one that
produced it.
