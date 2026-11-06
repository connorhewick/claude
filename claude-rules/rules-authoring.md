---
paths:
  - "**/.claude/rules/**/*.md"
  - "**/claude-rules/**/*.md"
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
---

# Writing a rule that records a decision

A document binds only a session that reads it; a rule arrives in context when the code it governs
is touched.

- **A heading per decision**, written as the ruling itself, not "Availability design".
- **The rule in a sentence or three**, stating what holds.
- **`**Why (YYYY-MM-DD):**` beneath it**: the constraint that made the decision non-obvious.
  Without the why, the next session re-litigates or reverses it.
- **No Status, Alternatives or Consequences.** What was weighed belongs in the commit and the PR.
- **A new rule gets its own file only when its `paths:` differ from every existing file's.**
  Same glob, same moment: add a section to that file.
- **Scope `paths:` to the narrowest tree the rule governs.** A rule with no `paths:` loads every
  session; keep those few and short.
- **Reversing a decision means editing or deleting its section.** Never mark it superseded.
- **A rule and the code disagreeing means one is a defect.** Treat a stale rule as a bug.
- **Contradictory rules are worse than a missing one.** Grep the directory for any rule a new
  one might contradict.
