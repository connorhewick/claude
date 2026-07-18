# spec-first-planning

**Type:** skill · installs to `~/.claude/skills/spec-first-planning/`

Turns a goal into a short spec and an ordered checklist before any editing starts. Delegates the
actual plan-drafting to the `planner` subagent (read-only, can't write files) so the plan is
grounded rather than rationalized after the fact. Presents the checklist for approval before
implementation begins.

Auto-invoked for non-trivial, multi-step tasks, or run explicitly with `/spec-first-planning`.
Pairs with the [`planner`](../planner) agent — install both together.
