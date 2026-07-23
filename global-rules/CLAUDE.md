# Global engineering config

Personal, cross-project defaults for Claude Code, installed at `~/.claude/CLAUDE.md` so they
load in every project on this machine. Intentionally stack-agnostic: no project- or
company-specific rules live here — those belong in a project's own `AGENTS.md` / `CLAUDE.md`.

This file is a component from the `connorhewick/claude` repo. To (re)install or update it, run
`./install.sh global-rules` from that repo — it backs up any existing `~/.claude/CLAUDE.md`
first. Edit your own additions below the marked line; a re-install will not silently discard a
file it can't back up.

## Working method (every project)

- Plan-first on non-trivial work (3+ steps or an architectural choice): write a short spec and a
  checklist before editing. If the approach stops working, stop and re-plan rather than pushing
  on. See "spec first planning" below for the process, including when to skip it.
- Keep the main context clean by delegating research, parallel investigation, and isolated
  multi-step work to subagents — one focused task per subagent, not a vague "look into X."
  - Delegate when the work is read-only investigation, spans independent areas that can run in
    parallel, or would otherwise pollute the main context with exploration detail the parent
    doesn't need to keep. Keep it inline when the task needs to interview the user (subagents
    can't call `AskUserQuestion`), needs context the parent has already built that costs more to
    re-derive than to reuse, or is a single trivial step.
  - Get approval before dispatching, whenever delegation looks warranted: present the plan —
    what each subagent will do and why it's not just done inline — plus an explicit read on
    whether the extra cost (see the fan-out cost note below) is worth it for this task. Wait for
    the user to approve or decline the strategy before dispatching anything.
  - Hand off relevant components rather than expecting a subagent to find them: before
    dispatching, identify which installed skills/rules the task needs and put their names and
    operative instructions directly in the subagent's prompt.
  - Run independent subagents in parallel, in one dispatch; run them sequentially only when one
    needs a prior one's output. Converge results back in the main session before acting on them.
  - Parallel fan-out isn't free just because it's parallel: each subagent starts cold and
    re-derives shared context (the same file, the same codebase scan) independently, so total
    tokens across N subagents run roughly N× a serial equivalent — it buys wall-clock time and
    keeps the parent's context clean, not a smaller total. Reserve wide fan-outs (many subagents
    over the same corpus) for genuine one-shot broad surveys; don't reach for one as the default
    shape for routine per-task delegation.
- Definition of done: a change is done only when the relevant checks/tests pass, a human has
  reviewed and approved it, and the task's stated acceptance criteria are met — none of these
  alone is sufficient. Don't declare something done on partial satisfaction of this list.
- Code walkthrough + interview (human in the loop): before handing a non-trivial change off for
  review or a PR — and before treating it as done — walk the human through it and interview them
  for the decisions only they can make. This is the mechanism for the "a human has reviewed and
  approved" clause above, and the convergence checkpoint when work is fanned out across parallel
  agents. Don't skip it on multi-file, cross-cutting, or hard-to-reverse changes. Run it in three
  steps:
  1. **Walkthrough** — narrate the change in review order: the problem it solves, the key files
     and the path through them, and the decision points or trade-offs taken along the way.
     Reference code as `file:line`. Lead with the shape of the change, not a line-by-line dump.
  2. **Interview** — ask the questions whose answers you couldn't safely assume: choices between
     viable approaches, scope you're unsure is in or out, and anything you inferred rather than
     were told. Use `AskUserQuestion`; record deferred answers as open questions instead of
     guessing.
  3. **Incorporate** — apply the human's answers before converging the change or opening the PR.

  Skip it only for trivial changes (typos, one-line fixes) where there is nothing to decide.
- Justify any new dependency before adding it: state the alternatives considered (including the
  standard library/existing project dependencies) and why this one wins.
- Prefer Claude Code's own native, built-in mechanisms over a hand-rolled workaround that
  duplicates what the CLI already provides — check whether a built-in capability covers the need
  before improvising one. Your knowledge of the CLI's feature set can lag the installed version;
  when a capability question actually matters to the task (a workaround feels necessary, or the
  user asks what Claude Code can do), verify against the current changelog (WebFetch
  `raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`) rather than relying
  solely on training-data recall.
- In any given project, follow that project's own stated conventions
  (`AGENTS.md`/`CLAUDE.md`/`.claude/rules/*.md`) over these defaults.

Git/version-control conventions (commit format, branching, worktrees, PR hygiene) live in the
separate `git-rules` component, not here — see `~/.claude/rules/git-rules.md`.

<!-- Add your personal preferences below this line; re-running install.sh global-rules backs up
     the whole file before replacing it, so your additions are recoverable from the .bak copy. -->

## spec first planning

Before making changes for a non-trivial task, produce a short spec and an ordered checklist —
don't start editing files first.

1. Restate the goal in one or two sentences, and list anything ambiguous or undecided as an
   open question rather than silently picking an answer.
2. Produce the plan yourself, grounded in the current project's actual conventions and
   constraints — any stated definition of "done" and version-control/documentation conventions
   in `AGENTS.md`/`CLAUDE.md`, and path-scoped rules in `.claude/rules/*.md` relevant to the paths
   the plan touches. Delegate to a dedicated planning subagent instead, only if the session
   already has one available for this project.
3. Present the resulting checklist to the user before starting implementation. Get open
   questions resolved first.
4. Keep the plan itself stack-agnostic unless the user's request already commits to a
   language/framework/tool.

Do not skip straight to implementation on a multi-step task just because the shape of the
change seems obvious — a wrong early assumption is more expensive to unwind after code exists.

**Exception:** skip this entirely for a single-file, mechanically-scoped fix — a well-understood
bug with an obvious fix, a lint/warning/format cleanup, a small change with no competing approach
to choose between — even if it takes several edits. The dividing line is whether a decision
exists that only the user could make (an approach choice, an ambiguous scope, a hard-to-reverse
call); if there isn't one, the plan would just restate the diff back to the user before making it.

Documentation conventions (ADRs, ticket/doc naming) live in the separate `documentation-rules`
component — see `~/.claude/rules/documentation-rules.md`. SwiftUI conventions live in
`swiftui-rules` — see `~/.claude/rules/swiftui-rules.md`.
