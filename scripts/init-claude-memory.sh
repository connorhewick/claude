#!/usr/bin/env bash
# Seed the `claude-memory` orphan branch that the PR walkthrough workflow
# (.github/workflows/claude-pr-review.yml) writes plans + TODOs to.
#
# Run once, from a clean working tree, in the repo root. Idempotent: if the
# branch already exists on the remote it exits without touching it.
#
# Usage: scripts/init-claude-memory.sh [remote]   (default remote: origin)
set -euo pipefail

remote="${1:-origin}"
branch="claude-memory"

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "init-claude-memory: must be run inside a git repo" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "init-claude-memory: working tree is dirty; commit or stash first" >&2
  exit 1
fi

if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null 2>&1; then
  echo "init-claude-memory: $remote/$branch already exists — nothing to do."
  exit 0
fi

workdir="$(mktemp -d)"
trap 'git worktree remove --force "$workdir" 2>/dev/null || true; rm -rf "$workdir"' EXIT

git worktree add --detach "$workdir"
(
  cd "$workdir"
  git checkout --orphan "$branch"
  git rm -rf . >/dev/null 2>&1 || true

  mkdir -p walkthroughs completed

  cat > WALKTHROUGHS_TODO.md <<'MD'
# Code walkthroughs — pending

This file is maintained by the PR walkthrough workflow
(`.github/workflows/claude-pr-review.yml` on the default branch) and by live
Claude Code sessions that finish walkthroughs. Do not edit by hand except to
correct obvious mistakes.

To run one, tell Claude in a session: **"walk me through PR-<N>"**. Claude will
read the plan below, walk you through the change, interview you on the
decision points, and only then post advisory comments to the PR.

## Pending

<!-- CI appends entries here. Format: -->
<!-- - [ ] [PR-<N>: <title>](walkthroughs/PR-<N>-<slug>.md) — <date> (<trigger>) -->

## Recently completed

<!-- Live sessions move entries here after posting the advisory review. -->
MD

  cat > walkthroughs/README.md <<'MD'
# Walkthrough plan format

Each pending walkthrough is one file: `PR-<number>-<slug>.md`. The auto-review
workflow writes it; a live Claude Code session reads it later to walk the
human through the change before posting anything to the PR.

## Required sections

```markdown
# Walkthrough plan — PR-<N>: <title>

- **PR**: <url>
- **Author**: @<login>
- **Base**: <base-ref> @ <sha>
- **Head**: <head-ref> @ <sha>
- **Generated**: <iso-8601>
- **Trigger**: <review_requested | assigned | mention_in_body | mention_in_comment | mention_in_review_comment | synchronize>

## Summary

<1-3 sentences: what the PR does and why, in the reviewer's frame.>

## Shape of the change

<Paragraph on the overall structure — what abstractions moved, what
surface expanded, what the entry point is. Not a line-by-line dump.>

## Walkthrough (review order)

1. `path/to/file.ext:LN` — <what happens here, why it matters>
2. `path/to/other.ext:LN` — <...>
3. ...

## Decision points to interview on

- <A choice between viable approaches, or scope the reviewer inferred
  rather than was told. One bullet per question.>
- <...>

## DRAFT advisory findings — do not post until walkthrough+interview complete

- [ ] `path/to/file.ext:LN` — <category>: <one-sentence defect + failure
      scenario>. **Confidence**: low/medium/high.
- [ ] ...
```

## Conventions

- Every code reference uses `file:line` so the human can navigate directly.
- Findings are DRAFT. The human's answers during the interview promote,
  refine, or drop them before anything is posted.
- "Advisory" reviews only. Do not draft `REQUEST_CHANGES` or `APPROVE`
  reviews unless the human explicitly asks for one.
- If the diff references a file that isn't in the PR (config, generated
  fixture, etc.), record that as a decision point — do not invent context.
MD

  git add WALKTHROUGHS_TODO.md walkthroughs/README.md
  git -c user.name="claude-pr-review[bot]" \
      -c user.email="claude-pr-review@users.noreply.github.com" \
      commit -m "chore: seed claude-memory branch for PR walkthrough plans"
  git push "$remote" "$branch"
)

echo "init-claude-memory: seeded $remote/$branch."
