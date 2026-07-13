---
paths:
  - "**"
---

# Pending PR walkthroughs

An auto-review workflow (`.github/workflows/claude-pr-review.yml`) queues advisory
walkthrough plans on the `claude-memory` branch whenever @connorhewick is tagged,
assigned, or requested as a reviewer on a PR. When the human is ready, a live Claude
Code session picks up a plan, runs the walkthrough+interview from `AGENTS.md`, and
only then posts consolidated advisory comments to the PR.

## Storage layout (on the `claude-memory` branch)

```
WALKTHROUGHS_TODO.md          # top-level list; check this first
walkthroughs/README.md        # format spec for plan files
walkthroughs/PR-<n>-<slug>.md # one plan per pending walkthrough
completed/PR-<n>-<slug>.md    # archived after the human finishes a walkthrough
```

The `claude-memory` branch is orphaned from `main` — it never merges anywhere.
Do not attempt to rebase, merge, or open a PR against it.

## When to consult this

- The user asks "what walkthroughs are pending?", "any PRs to review?", "walk me
  through PR-N", or similar.
- The user tags you into a PR review session.
- On session start, if there is signal that walkthrough work is expected (a
  `claude-memory` remote is present and the user's recent activity mentions PR review).

Do NOT poll or fetch `claude-memory` on every session — only when the user's
request is about PR review or walkthroughs.

## Procedure — running a queued walkthrough

1. **Fetch the memory branch into a worktree** so it doesn't disturb the current
   working tree:
   ```
   git fetch origin claude-memory
   git worktree add /tmp/claude-memory origin/claude-memory
   ```
2. **Read `/tmp/claude-memory/WALKTHROUGHS_TODO.md`** and pick the entry the
   user is asking about (or list the pending entries if they haven't chosen).
3. **Read the plan file** at `/tmp/claude-memory/walkthroughs/PR-<n>-<slug>.md`.
   The plan contains: summary, review order with `file:line` refs, decision
   points, and DRAFT advisory findings.
4. **Walk the human through it** in review order per the `AGENTS.md` "Code
   walkthrough + interview" convention. Reference code as `file:line`. Lead with
   the shape of the change.
5. **Interview** using `AskUserQuestion` for every decision point in the plan.
   Record deferred answers as open questions, do not guess.
6. **Consolidate findings** — apply the human's answers to the DRAFT findings.
   Drop findings the human dismissed. Sharpen findings they refined.
7. **Confirm before posting** — show the human the final comment set and get
   explicit approval to post. This is a "risky action visible to others" per
   the Claude Code executing-actions-with-care rules.
8. **Post to the PR** — use the GitHub MCP tools
   (`mcp__github__pull_request_review_write` with method `create` to open a
   pending review, `mcp__github__add_comment_to_pending_review` for each
   line-anchored finding, then `pull_request_review_write` with method
   `submit_pending` and event `COMMENT` — advisory, never `REQUEST_CHANGES` or
   `APPROVE` unless the human asks for it).
9. **Archive the plan**:
   ```
   cd /tmp/claude-memory
   git mv walkthroughs/PR-<n>-<slug>.md completed/PR-<n>-<slug>.md
   ```
   Update `WALKTHROUGHS_TODO.md`: move the entry from "Pending" to "Recently
   completed" with today's date.
   ```
   git -c user.name="..." -c user.email="..." commit -m \
       "chore(walkthrough): complete PR-<n>"
   git push origin HEAD:claude-memory
   ```
10. **Clean up the worktree**: `git worktree remove /tmp/claude-memory`.

## Guardrails

- **Never** modify a walkthrough plan file to make it "look better" without the
  human's input — the plan is CI's draft; edits to it must come from the
  interview.
- **Never** post to a PR without the human's explicit approval on the final
  comment set. "Advisory" means the human's voice, not the auto-review's raw
  output.
- **Never** open a PR from `claude-memory`. It is an orphan branch by design.
