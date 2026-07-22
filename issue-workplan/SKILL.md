---
name: issue-workplan
description: >
  Turn one or more GitHub issues into a self-contained workplan document for a fresh or
  autonomous session to implement later — resolving every ambiguity now, since the session that
  executes the plan has nobody to ask. Works the same for a single issue as for a batch; only
  the execution-order step becomes trivial. Triggers for: "plan out these issues", "make a
  workplan for #X #Y", "write a workplan for issue #N for later", "prep an autonomous session for
  this label/milestone/issue", "sequence these issues into a plan", "turn this backlog into a
  workplan". Do NOT trigger when you're about to implement the issue yourself right now in this
  session, regardless of issue count (that's ordinary spec-first planning, no doc needed), for an
  end-of-session retrospective (that's `session-handoff`), or for a PRD/ADR covering one decision
  or feature (that's `write-prd`/`write-adr`).
argument-hint: >
  [issue numbers/URLs | label | milestone | "all"]
---

Produce `docs/workplans/NNNN-slug.md` — a workplan covering one or more GitHub issues, written
so a session with no memory of this conversation (a fresh session, or an unattended autonomous
one) can execute it without needing to ask anyone anything. That last part is the operating
constraint for every step below: this skill's own session can interview the user right now: the
session that later executes the plan cannot. Any ambiguity not resolved here becomes a silent
wrong guess later — resolve it here, or mark the whole plan incomplete and stop.

## 1 — Resolve issue selection

Accept any of:
- Explicit issue numbers or URLs the user names.
- A label or milestone the user names — resolve via `gh issue list --state open --label <label>`
  or the milestone equivalent.
- "All open issues" — **only** when the user explicitly says so. Never default to the full
  backlog just because no selector was given; ask which issues if it's not clear.

## 2 — Read each issue in full

For every selected issue, fetch title, body, labels, and comments — not just the title:
`gh issue view <n> --json title,body,labels,comments`. This repo's own issue history shows
titles routinely undersell real intent (a one-line title turning into a materially different
scope once its body and discussion are read) — never plan from a title alone.

## 3 — Resolve every ambiguity now

For each issue that is underspecified, presents a genuine choice between approaches, or has
scope only the user can decide (the same bar `CLAUDE.md`'s spec-first planning uses for "open
questions"), interview the user with `AskUserQuestion` before including it in the plan. Bake the
resolved answer into that issue's section of the workplan as a stated decision — not as a
carried-forward open question. If the user defers an answer, say the workplan is incomplete
pending that decision rather than guessing on the executing session's behalf, and leave that
issue out of the written doc until it's resolved.

## 4 — Sequence the issues

If only one issue was selected, this step is trivial — a single-entry execution order, no
dependency or parallelization analysis needed — skip straight to step 5. Otherwise, determine
across the selected set:
- **Dependencies** — does one issue's output feed another (shared files, one issue's decision
  gating another's scope)? Order dependent issues accordingly.
- **Parallelizable groups** — which issues are independent enough to hand to separate sessions/
  subagents at once, per this repo's own fan-out guidance in `~/.claude/CLAUDE.md` (worth it only
  for genuinely independent work, not routine per-task delegation).
- **Priority** — if issues carry an explicit priority (as this repo's own issues do, in a
  "**Priority: PN**" line), let it inform ordering within a dependency tier, not override one.

## 5 — Write the workplan document

Save to `docs/workplans/NNNN-slug.md` (next unused four-digit number in `docs/workplans/`, start
at `0001` if the directory doesn't exist yet). Structure:

```markdown
# Workplan NNNN: <short title for the batch>

Date: <YYYY-MM-DD>
Source issues: #<n>, #<n>, ...

## Execution order

1. #<n> — <one-line scope> (blocks: #<n>; parallelizable with: #<n>)
2. ...

## Per-issue detail

### #<n> — <issue title>

**Resolved scope:** <the concrete decision(s) reached in step 3 — not the original ambiguous
ask, the resolved one>

**Acceptance criteria:** <what "done" means for this issue, concretely>

**Steps:**
- [ ] ...

**Files/areas likely touched:** <paths, components, directories>

## Decisions made during planning

- <question that was ambiguous> → <resolved answer> — <why, if non-obvious>
```

Every "Resolved scope" and "Decisions made" entry must read as a closed decision, not a
proposal — the executing session should never have to re-derive or guess at something already
settled here.

## 6 — Hand off

Report the doc's path back to the user. This skill does not execute the plan itself, open
issues/PRs, or spawn the autonomous session — that's a separate, deliberate follow-up action.

## Guardrails

- Never leave a "TBD", "ask the user", or unresolved branch point in the written doc — that
  defeats the entire point of planning for a session that can't ask.
- Don't silently expand scope to "all open issues" without an explicit request for that.
- Don't plan an issue whose real scope you couldn't pin down in step 3 — say so and leave it out
  rather than guessing.
- This skill produces a document; it does not implement anything itself.
