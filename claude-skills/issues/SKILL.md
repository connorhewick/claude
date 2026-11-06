---
name: issues
description: >
  Pick up, file or cross-reference issues and tickets. Use when starting work from an issue,
  when the user says "file an issue", "open a ticket", "work on #n", "pick up this issue", or
  when a change overlaps existing issues. Not for the PR itself or reviewing others' work
  (review-pr).
allowed-tools: Bash(gh issue *), Bash(gh label list *), Bash(git *), Read, Grep, AskUserQuestion
---

The next person to pick up an issue reads it without this session. Each step keeps them from
duplicating work or missing context.

## 1. Picking one up

- **Read the whole issue including its comments** (`gh issue view <n> --comments`). The
  acceptance criteria are usually in a comment, not the body.
- **Assign it to yourself when you branch**, not at commit time, so no one else picks it up. If
  it already has an assignee, stop and ask.
- Branch `<type>/issue-<n>-<slug>`, and carry the number to the PR's `Closes #<n>`.

## 2. Filing one

- **Labels are lowercase kebab-case**, matching the repo's existing convention
  (`gh label list`). Never prose-cased; never a new label where an existing one fits.
- **Reference tickets and documents by descriptive name** — `PROJ-142-oauth-token-refresh`, not
  `PROJ-142`.

## 3. Cross-referencing

**When a new issue overlaps others, comment on those issues too** — without being asked. Write
each cross-reference from *that* issue's position in the chain: what blocks it, what it blocks,
where it sits in the order. No identical boilerplate; a reader sees only that issue.

## 4. Keeping count

Keep a running list of issues filed in the session and surface it after each one.
