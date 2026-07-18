---
name: write-prd
description: >
  Use this skill at the very start of a greenfield project or a major/minor feature, before any
  planning or code. It interviews the user to uncover the underlying need, then writes a Product
  Requirements Document capturing the problem, users, goals, scope, and open questions. Triggers
  for: "start a new project", "define the product", "write a PRD", "product requirements",
  "I want to build X", "new feature", "figure out the requirements", "scope this out". Covers
  problem framing, user/persona discovery, success metrics, non-goals, and constraints, then
  hands off to plan-first work. Do NOT trigger for trivial changes (typos, one-line fixes,
  obvious bugs), when a PRD for this work already exists, or for a pure implementation request
  where requirements are already settled.
argument-hint: >
  [product-or-feature name]
---

Turn a raw need into a Product Requirements Document by interviewing the user, then hand the
approved PRD to plan-first work. This runs *before* planning: it decides *what* to build
and *why*; planning decides *how*.

This skill runs inline in the main session — not via a subagent — because the interview needs
live `AskUserQuestion` round-trips, and subagents can't prompt the user.

## Procedure

1. **Frame & qualify.** Restate in one sentence what the user wants to build. If it's a trivial
   change (typo, one-liner, obvious bug fix) or the requirements are already settled, say a PRD
   is overkill and stop — don't force the process. Otherwise note whether this is a greenfield
   project or a major/minor feature, since that sets how deep the interview goes (a minor
   feature needs one light round, not three).

2. **Interview in adaptive rounds** with `AskUserQuestion` (batch related questions, max 4 per
   call). Infer from what the user already told you and only ask what's genuinely undecided —
   an interview that re-asks answered questions is worse than no interview. Let each answer
   shape the next question, and offer a recommended option first where a sensible default
   exists. Work through these dimensions, collapsing or skipping rounds when the scope is small:

   - **Round 1 — Problem & audience:** What problem or pain is this solving? Who has it
     (users/personas, and their context)? Why does it matter now / what happens if it's not
     solved?
   - **Round 2 — Solution shape & success:** What are the core capabilities or jobs-to-be-done?
     What does success look like, and how is it measured? What's explicitly *out* of scope
     (non-goals) — naming non-goals early prevents scope creep later.
   - **Round 3 — Constraints & risks:** What hard constraints apply (regulatory, technical,
     timeline, systems it must integrate with)? What are the key assumptions and risks? What's
     still open?

   When the user leaves something undecided, record it under **Open questions** in the PRD
   rather than silently picking an answer — the same discipline plan-first work uses. A
   deferred decision surfaced is better than a wrong one buried.

3. **Write the PRD** to `docs/prd/NNNN-slug.md`, where `NNNN` is the next unused four-digit
   number in `docs/prd/` (start at `0001` if the directory doesn't exist) and `slug` is the
   product/feature name kebab-cased. Use the template below. Keep it stack-agnostic unless the
   user's request already commits to a specific language, framework, or tool.

4. **Review.** Present the PRD and let the user amend it before moving on. Requirements are
   cheap to change here and expensive to change after planning and code exist.

5. **Hand off.** Once the user approves the PRD, apply the plan-first working method (short spec
   + ordered checklist, per `~/.claude/CLAUDE.md`) to the PRD as the goal input, so the approved
   requirements flow straight into a spec and checklist.

## PRD template

Note the Table of Contents sits immediately after the title and one-line description, per the
project's documentation convention. Keep the anchors in sync if you rename a section.

```markdown
# NNNN. <Product / feature name>

<One-line description of what this is and who it's for.>

Date: <YYYY-MM-DD> · Status: Draft

## Table of Contents
- [Overview](#overview)
- [Target users](#target-users)
- [Goals & success metrics](#goals--success-metrics)
- [Non-goals](#non-goals)
- [User stories & core flows](#user-stories--core-flows)
- [Functional requirements](#functional-requirements)
- [Constraints & dependencies](#constraints--dependencies)
- [Assumptions & risks](#assumptions--risks)
- [Open questions](#open-questions)

## Overview
<Problem statement: the need, who has it, why it matters now.>

## Target users
<Primary users / personas and the context they operate in.>

## Goals & success metrics
<What success looks like and how it's measured.>

## Non-goals
<What is explicitly out of scope for this work.>

## User stories & core flows
<Key jobs-to-be-done, written as user stories.>

## Functional requirements
<What the product must do — numbered and testable.>

## Constraints & dependencies
<Regulatory, technical, timeline, and integration constraints.>

## Assumptions & risks
<What we're assuming to be true; what could go wrong.>

## Open questions
<Unresolved items the user deferred, to settle before or during planning.>
```
