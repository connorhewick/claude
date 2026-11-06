---
name: walkthrough
description: >
  Narrate a finished or nearly finished change in review order, interview the user on every
  decision that couldn't safely be assumed, and incorporate the answers before the change is
  shipped. Use before opening a PR, before calling a non-trivial change done, or when the user
  says "walk me through it", "what did you decide", "before we ship". Not for trivial changes,
  and not from inside ship.
allowed-tools: Bash(git *), Read, Grep, Glob, AskUserQuestion
---

The reviewer wasn't in this session. This is where the reasoning gets out of the chat and every
inference is checked before it becomes a commitment.

## 1. Walkthrough

Narrate the change in review order:

1. **The problem it solves**, in two sentences, restated from the issue or the brief — not from
   the diff.
2. **The key files and the path through them**, as `file:line`. Lead with the shape: what talks
   to what, what boundary was touched. Not a line-by-line dump.
3. **The decisions and trade-offs**, each as: what was chosen, what the alternative was, why
   this one. If a decision meets the recording bar in `CLAUDE.md`, say whether and where a rule
   was written.
4. **What was verified, and how.** The commands run, the counts observed, the branch tip.

Ground it in evidence: `git diff --stat origin/<default>...HEAD` and the real file list, not a
recollection of them.

## 2. Interview

Ask only what you couldn't safely assume: a question is worth asking if different answers lead to
materially different work. One at a time, with a recommendation on each:

- choices between viable approaches you made without being told;
- scope you're unsure is in or out;
- anything you inferred rather than were told;
- categories of risk the brief didn't name and you found.

Record a deferred answer as an open question in the PR body's **Known and accepted**, never as a
guess.

## 3. Incorporate

Apply the answers before converging the work or opening the PR. If an answer changes the
approach, say so and return to step 1 for the parts it touched. Then hand off to `ship`.
