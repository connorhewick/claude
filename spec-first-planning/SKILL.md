---
name: spec-first-planning
description: Turn a goal into a spec and checklist before writing any code. Use when starting a non-trivial, multi-step task, or when the user asks for a plan before implementation.
---

Before making changes for a non-trivial task, produce a short spec and an ordered checklist —
don't start editing files first.

1. Restate the goal in one or two sentences, and list anything ambiguous or undecided as an
   open question rather than silently picking an answer.
2. Delegate to the `planner` subagent (the `Agent` tool, `subagent_type: planner`) with the
   restated goal, so the plan is produced by a role that cannot write files and is grounded in
   `AGENTS.md` and the relevant `.claude/rules/*.md`.
3. Present the resulting checklist to the user before starting implementation. Get open
   questions resolved first.
4. Keep the plan itself stack-agnostic unless the user's request already commits to a
   language/framework/tool.

Do not skip straight to implementation on a multi-step task just because the shape of the
change seems obvious — a wrong early assumption is more expensive to unwind after code exists.
