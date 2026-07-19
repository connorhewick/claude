---
name: session-handoff
description: >
  Generate two documents at the end of a work session: a structured markdown handoff capturing
  the session's context — decisions, changes, open issues, next steps, key files — so a fresh
  session can pick up exactly where this one left off; and a harness-feedback doc capturing what
  worked and what didn't about the Claude Code setup itself (which skills/rules fired and helped,
  friction points, gaps worth building), saved outside the project for later review when
  improving the harness. Triggers for: "handoff", "session summary", "context transfer", "wrap
  up session", "save session state", "pick this up later", "pass this to another session", "end
  of day summary", "session checkpoint", or when the user signals they're stopping for now after
  substantive work. Do NOT trigger for a routine end-of-turn summary of a small change — this is
  for preserving state across a session boundary, not a status update.
allowed-tools: Bash(git *), Bash(.claude/skills/session-handoff/scripts/gather_context.sh *), Read, Write
---

Write two self-contained markdown documents at the end of a session: a **handoff** doc so a
fresh session can continue this work without re-discovering decisions already made, and a
**harness-feedback** doc capturing what to keep/change about the Claude Code setup itself — kept
separate from the project's own docs, since it's feedback on the tooling, not the codebase.

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
priority for next session?" While you're at it, note anything already surfaced in-session about
the tooling itself — a skill that mis-fired or over-fired, a rule that didn't apply cleanly, a
manual step you wish had been automatic — that feeds the harness-feedback doc in step 4.

## 3 — Write the handoff document

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

## 4 — Write the harness-feedback document

Save to `$CLAUDE_CONFIG_DIR/harness-feedback/` if that env var is set, otherwise
`~/.claude/harness-feedback/` — outside the current project, since this is feedback about
Claude Code and its installed components (skills/rules/agents), not about the project's code.
Filename: `YYYY-MM-DD-<project-name>.md`, where `<project-name>` is the current repo's top-level
directory name (`git rev-parse --show-toplevel`, or the cwd's basename if not a git repo).

Only write what's concrete and specific to *this* session — skip a section entirely rather than
padding it with a generic "things went well" when nothing stood out either way.

```markdown
# Harness Feedback — [Project Name]

**Date:** YYYY-MM-DD
**Session focus:** one line — what the session was actually working on

## Worked well

Specific components (by name) or harness behaviors that helped, and why — concrete enough to
reinforce, not "the AI was helpful."

## Friction

Specific moments something didn't fire when it should have, fired when it shouldn't have,
produced the wrong shape of output, or required a manual workaround. Name the component (or
note "no relevant skill existed") and the exact moment it happened.

## Gaps / wishlist

A skill, rule, or agent that doesn't exist yet but would have helped — described from the
concrete moment in this session that would have used it, not a speculative feature request.

## Suggested changes to existing components

A specific skill/rule whose trigger phrasing, scope, or content should be tightened, and why —
one line each.
```

## Edge cases

- **No git repo** — skip git auto-detection; lean on conversation history and any files created.
- **Exploration/spike session** — "What Was Done" becomes findings/learnings; "Decisions" may be
  tentative recommendations rather than settled choices.
- **Multi-day continuation** — if a previous handoff exists, read it first and build on it rather
  than starting fresh; note what changed since.
- **Very long session** — don't try to capture everything. Focus on decisions, final state, next
  steps; summarize file changes at a higher level. Keep the whole document under ~200 lines.
- **Nothing notable about the harness this session** — write a short harness-feedback doc saying
  so rather than fabricating friction or wishlist items to fill sections; an empty-but-honest
  doc is a valid result.
