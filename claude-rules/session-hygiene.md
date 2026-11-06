# Sessions, context and the state of the tree

Always-on. This file owns *verification of repository state* and *subagent fan-out*; other files
point here.

## Verify, don't assume, at the start

In a git checkout, one line at session start: branch, whether the tree is clean, and what you
can and can't see. Check rather than infer, even minutes in:

```sh
git status --porcelain
git branch --show-current
git log --oneline -5
git fetch origin --quiet && git status -sb     # local vs remote before switching or rebasing
```

- Open PRs whose branch matches the task: resume the work rather than restart it.

## Re-verify before anything irreversible

The tree at commit time is not the tree at session start. Re-run the checks above immediately
before committing, pushing, rebasing or opening a PR.

**A commit in your range you don't recognise is someone else's. Stop and ask.** It can be
shipped or split, but not un-mixed once a PR is open.

## When to start fresh

- **Decide from a number.** Run `/context` before compacting or starting over: often one tool
  result is the problem, not the session's length.
- **Start fresh** when the task changes, when accumulated context is no use to the next task, or
  when configuration changed underneath the session — hooks and settings load at session start.
- **Continue** when the accumulated context is the value: a debugging session that has narrowed a
  cause, an interview whose answers shape the work.
- Before ending a session with work in flight, write the handoff in the PR body or the issue,
  never only in chat: what's done, what's next, what was decided and why.

## Subagents and fan-out

`CLAUDE.md` says when to delegate; this says how.

- **Tier to the failure mode.** Smallest model for mechanical, verifiable work. Mid for
  implementing a settled spec. Largest for review, debugging, choosing between approaches, and
  anything whose error reading the output wouldn't catch.
- **Fresh agent** for a self-contained task; **fork** when re-deriving the conversation costs more.
  **Worktree** for any writer. Never re-delegate from inside a subagent.
- **A subagent inherits no rules or context.** Put in its prompt the governing rules, the
  acceptance criteria verbatim, and the branch and base it owns.
- **Fan-out buys wall-clock, not tokens**: N agents over one corpus cost about N× serial. State
  the cost in the disclosure line; dispatch independent agents in one call.
- **What comes back is a claim.** Spot-check each load-bearing one against the artefact.
- **Parts of one change get one integration branch.** Cut `integration/<slug>` from the fetched
  default branch and push it *before* dispatching; children branch from it, never the default
  branch, and rebase onto it as siblings land. Merge children one at a time (rebase, fast-forward,
  no force) and run the checks after each. Cut a failing child and re-branch it as its own change.
- **Only the integration branch opens a PR**, against the merged result. The body
  adds one line per child in merge order, what was cut and why, and test results for the merged
  result only. After merge, delete the integration and child branches and the worktrees.
  Standalone changes get their own PRs — don't batch unrelated work.
