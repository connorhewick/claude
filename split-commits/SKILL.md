---
name: split-commits
description: >
  Break an uncommitted working tree that spans multiple distinct tasks into one
  logical, atomic commit per concern instead of a single mixed commit. Triggers
  for: "commit these changes", "split this into commits", "these are different
  tasks", "make atomic commits", "break up this commit", "commit my work". Groups
  changes by intent (path-level, with hunk-level splitting when one file mixes
  concerns), proposes a plan with Conventional Commit messages, and — only after
  you approve — stages and commits each group. Never pushes; never commits without
  approval. Do NOT trigger when the tree is already one coherent change, or to
  amend/rebase existing commits.
allowed-tools: Bash(git *), Read, Grep, Glob, Write
---

Turn a mixed working tree into a sequence of atomic commits — each one a single coherent
concern that could stand on its own in review. This is the default path whenever you commit
work that spans more than one task; a genuinely single-purpose tree just gets one commit.

## Preconditions (check first, bail early)

- **Not on the default branch.** If `git rev-parse --abbrev-ref HEAD` is `main`/`master`, stop
  and offer to branch — all changes go through a branch and PR (`AGENTS.md`).
- **No rebase/merge in progress** (`git status` clean of conflict markers). If one is active,
  stop.
- Record the starting point: `START=$(git rev-parse HEAD)`. Tell the user that everything this
  skill does is undoable with `git reset --soft $START` (commits are local and unpushed).

## 1 — Survey the changes

Gather the full picture, not just staged files:
`git status --porcelain`, `git diff` (unstaged), `git diff --cached` (staged), and the untracked
list. Read enough of the actual diff to understand *intent*, not just which files moved.

## 2 — Cluster by concern

Group changes by the task they serve, not merely by directory. Signals: files that change
together for one purpose; a feature vs. its docs vs. unrelated config; separate subsystems;
a bug fix mixed into a feature. Aim for commits that are each independently coherent.

When a **single file** carries hunks for two different concerns, plan to split it at the hunk
level (§4). If even that can't cleanly separate them (the concerns share a line, or interleave
so tightly that `-U0` still merges them), keep the file whole in one group and flag it — never
hand-edit a diff to force a split.

## 3 — Propose the plan and wait for approval

Present an ordered list of commits. For each: the Conventional Commit message
(`feat:`/`fix:`/`docs:`/…), the files it includes (mark any that are **partial**), and a one-line
rationale. Order so earlier commits don't depend on later ones. Then ask for explicit approval
(`AskUserQuestion`: approve / adjust grouping). Do not stage or commit anything before approval.

## 4 — Execute (after approval only)

Normalize the index once so staging is fully under your control: `git reset -q` (unstages
everything; the working tree is untouched). Then, for each group in order:

- **Whole files** (including new and deleted): `git add -A -- <paths>`.
- **Partial (hunk-split) files:** select only this concern's hunks and stage them via a
  zero-context patch. Default diff context can merge changes that are within ~6 lines into one
  hunk, so use `-U0` to separate them, and apply with `--unidiff-zero`:

  ```
  git diff -U0 -- <file> > "$tmp"          # $tmp from mktemp — a patch left in the tree can be swept into a later group's git add, or muddy the untracked-file survey
  # keep the file header + only the @@ blocks for this concern; drop the others
  git apply --cached --unidiff-zero --check "$edited"   # verify before applying
  git apply --cached --unidiff-zero "$edited"
  ```

  If `--check` fails, do not force it: fall back to committing that file whole in one group and
  tell the user which concern it got bundled into.
- Commit the staged subset only (never `git commit -a`): `git commit -m "<message>"`. The rest
  of the tree stays unstaged for later groups.

## 5 — Confirm

Run `git log --oneline` for the new commits and `git status` to show anything intentionally
left behind. **Never push** and never open the PR — that's a separate, explicit step. If the
user is unhappy with the result, `git reset --soft $START` restores the pre-split state with all
changes intact.
