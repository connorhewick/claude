# planner

**Type:** agent · installs to `~/.claude/agents/planner.md`

Turns a stated goal into a concrete, checked-off-able plan — a short spec plus an ordered task
checklist. Read-only (no `Write`/`Edit`/`NotebookEdit`): its output is the plan itself, not code.

Delegate to it (`Agent` tool, `subagent_type: planner`) when starting a non-trivial, multi-step
task that needs a plan before code changes. Used automatically by the
[`spec-first-planning`](../spec-first-planning) skill.
