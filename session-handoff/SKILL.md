---
name: session-handoff
description: >
  Generate a structured markdown handoff document capturing the current session's context —
  decisions, changes, open issues, next steps, key files — so a fresh session can pick up exactly
  where this one left off. Triggers for: "handoff", "session summary", "context transfer",
  "wrap up session", "save session state", "pick this up later", "pass this to another session",
  "end of day summary", "session checkpoint", or when the user signals they're stopping for now
  after substantive work. Do NOT trigger for a routine end-of-turn summary of a small change —
  this is for preserving state across a session boundary, not a status update.
allowed-tools: Bash(git *), Bash(.claude/skills/session-handoff/scripts/gather_context.sh *), Read, Write
---

Write a self-contained markdown document that lets a fresh session continue this work without
re-discovering decisions already made or re-reading files already understood.

## 1 — Auto-detect context

Run the bundled script to collect git state, recently modified files, and project structure in
one shot:

```
bash .claude/skills/session-handoff/scripts/gather_context.sh [project_root] [hours_lookback]
```

Default lookback is 8 hours. If it's unavailable or the project isn't a git repo, gather manually:
`git status && git diff --stat && git log --oneline -20 && git branch --show-current`.

Then review the conversation itself for what the script can't see: architecture decisions and
their rationale, problems hit and how they were resolved, open questions, and files that were
read or discussed but not changed.

## 2 — Fill gaps with the user

Summarize what was auto-detected and ask a couple of targeted questions to fill gaps — not an
interrogation. E.g. "I see we worked on X and Y — anything I'm missing?" or "Is [thing] the
priority for next session?"

## 3 — Write the document

Save to `docs/handoff-YYYY-MM-DD.md` (or `handoff-<feature-name>.md` if that's more identifiable),
following this template. Skip any section that would be empty or trivially obvious rather than
padding it — every sentence should carry a concrete artifact (a file path, function name,
command, or decision), not a vague status like "made some progress."

```markdown
# Session Handoff — [Brief Title]

**Date:** YYYY-MM-DD
**Branch:** `feature/xyz` (or note if on main)
**Status:** [In Progress | Blocked | Ready for Review | Spike/Exploration]

## Summary

2-4 sentences: the goal, how far we got, current state. Written for someone deciding in 10
seconds whether to read the rest.

## Decisions

For each: **Decision** — what was decided. **Rationale** — why, including alternatives rejected.
**Impact** — what this affects downstream. This is the highest-value section — without it, the
next session may re-litigate settled questions.

## What Was Done

By logical area, not chronologically. Reference specific files; include short snippets where they
illuminate the approach.

## What's Left (Next Steps)

Prioritized. Each item should have enough context (files to touch, gotchas) that the next session
can start immediately.

## Open Questions

Unresolved unknowns that need input before the next session can proceed.

## Key Files

| File | Role |
|------|------|
| `path/to/file` | Brief description |

## Current State of the Code

Anything half-implemented, temporary, or known-broken: failing tests, hacks, setup needed.

## How to Continue

Concrete first actions for the next session — what to read first, what to run.
```

## Edge cases

- **No git repo** — skip git auto-detection; lean on conversation history and any files created.
- **Exploration/spike session** — "What Was Done" becomes findings/learnings; "Decisions" may be
  tentative recommendations rather than settled choices.
- **Multi-day continuation** — if a previous handoff exists, read it first and build on it rather
  than starting fresh; note what changed since.
- **Very long session** — don't try to capture everything. Focus on decisions, final state, next
  steps; summarize file changes at a higher level. Keep the whole document under ~200 lines.
