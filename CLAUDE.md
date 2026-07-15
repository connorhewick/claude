@AGENTS.md

## Claude Code

Path-scoped rules live in `.claude/rules/*.md`. The verification contract
(`.claude/CONTRACT.md`, entrypoint `.claude/verify`) is the arbiter of "done."

## Feature branches and parallel work

Start every new feature on its own feature branch (naming and the never-push-to-default rule
are in `AGENTS.md` Version control; `.claude/hooks/guard-branch-name.sh` enforces the scheme) —
never build a new feature directly on the branch you happen to be on. When more than one
feature is active at once, give each its own git worktree via `EnterWorktree` (one worktree per
in-flight feature) rather than stashing or switching branches inside a single working tree, so
uncommitted work on one feature never blocks or bleeds into another. Use `ExitWorktree` —
`keep` to preserve a branch you'll return to, `remove` once it's merged or abandoned — to move
between them.

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

## SwiftUI previews

This repo has no SwiftUI code, so this rule is dormant here — it exists for consistency with
`~/.claude/CLAUDE.md`. Wherever SwiftUI code is touched: always include a working `#Preview` for
every `View` you write or edit — the SwiftUI equivalent of verifying a UI change in a browser
before calling it done. Keep the Xcode project's `ENABLE_PREVIEWS` build setting `YES` (the
modern Xcode default); don't disable it.
