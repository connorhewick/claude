@AGENTS.md

## Claude Code

Path-scoped rules live in `.claude/rules/*.md`. The verification contract
(`.claude/CONTRACT.md`, entrypoint `.claude/verify`) is the arbiter of "done."

## Code walkthrough + interview (human in the loop)

Before handing a non-trivial change off for review or a PR — and before treating it as done —
walk the human through it and interview them for the decisions only they can make. This is the
mechanism for the "a human has reviewed and approved" clause of the definition of done
(`AGENTS.md`), and the convergence checkpoint when work is fanned out across parallel agents.
Don't skip it on multi-file, cross-cutting, or hard-to-reverse changes.

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
