# Engineering conventions

Generic, cross-project conventions live in `~/.claude/CLAUDE.md` (the `global-rules` component,
loaded alongside this file in every session). This file holds only what's specific to
maintaining the claude component-repo itself.

## Definition of done (this repo's checks)

The "checks pass" clause of the Definition of done in `~/.claude/CLAUDE.md` means, for this repo:
a dry-run install/uninstall.

## Claude Code

This repo is a composable library of Claude Code components (skills, agents, rules) — see
`README.md` for the full catalog and `install.sh`/`uninstall.sh` usage. Each component lives in
its own top-level directory with its source file, which doubles as that component's
documentation (no separate per-component `README.md`); there is no project-level
`.claude/agents`/`.claude/skills`/`.claude/rules` in this repo itself; developing the components
doesn't require having them installed.

## Choosing a component type

Before adding a *new* component, first check whether the request actually belongs in an
*existing* one instead — most often, a new convention scoped to a language, framework, or
concern that's already covered by an existing `rule` component (e.g. a new SwiftUI convention
belongs in `swiftui-rules/rule.md`, a new git convention in `git-rules/rule.md`), or a new
cross-project default that belongs in `global-rules`'s own file (see the `global-rules` bullet
below). Only once nothing existing fits does a new top-level component get created.

Once that's ruled out, decide the new component's type from what triggers it and what scope it
needs — don't take a proposed type at face value:

- **rule** (`.claude/rules/*.md`): auto-applied and path-scoped. No invocation — Claude reads it
  automatically whenever the paths it declares are touched. Use for a standing constraint or
  convention scoped to particular files/directories (e.g. "always include a `#Preview` for
  SwiftUI views"). If the rule is scoped to a specific file type, language, or framework, its
  `rule.md` must carry `paths:` frontmatter matching that scope (e.g. `paths: ["**/*.swift"]`)
  so it only enters context in sessions that actually touch matching files, rather than loading
  unconditionally into every session regardless of relevance. A rule with no natural file-type
  scope — a cross-cutting concern like git/version-control or documentation conventions — can
  omit `paths` and load unconditionally instead; that's a deliberate choice for that kind of
  rule, not an oversight.
- **global-rules**: the one component that installs to `~/.claude/CLAUDE.md` itself — always
  loaded, every project, unconditionally, regardless of path. This repo has (and should only
  ever have) a single `global-rules` component; a new cross-project default is an addition to
  that component's own file, not a new top-level component.
- **skill** (`SKILL.md`): on-demand — invoked explicitly (`/name`) or auto-triggered when its
  `description` matches the user's intent. Use for a multi-step workflow with its own procedure,
  optional supporting files (references, scripts), and/or conditional logic (branches,
  checklists, preconditions).
- **agent** (`agent.md`): a dedicated tool/context scope, spawned via the `Task`/`Agent`
  mechanism rather than invoked directly by the user. Use when the value is isolating context
  (keeping a large search or investigation out of the main conversation) or restricting tool
  access — not when it's something the user names and runs directly.
- **slash command** (`command.md`): explicit-only, no auto-trigger, no branching logic — a
  static prompt template the user runs by name. Use when a skill would be overkill: nothing to
  trigger on automatically, no supporting files, no multi-step procedure to encode.
- **hook** (`hook.sh` + `hook.json`): runs on a harness event (`PreToolUse`, `PostToolUse`,
  `Stop`, …), not on anything Claude decides — it fires even if Claude never reads it. Use for an
  enforced, mechanical action (block/allow a tool call, run a formatter after edits) rather than
  guidance for Claude to weigh and possibly ignore.
- **output style** (`output-style.md`): rewrites the system prompt itself — role, tone, and
  default response shape for the whole session. Use only when the goal is changing *how Claude
  communicates* across every turn (e.g. a non-engineering persona); it's not for project
  conventions or a one-off task, which belong in `global-rules`/a `rule`/a `skill` instead.

This repo doesn't support MCP servers as a component type (no current use case) — don't propose
one without raising it first.

Run this decision every time a component is about to be added, including:
- when the user has already specified a type — check it against the criteria above rather than
  accepting it as given;
- when porting a component in from a different Claude config repo — its type there reflects that
  repo's own conventions, which may not match this repo's semantics (e.g. what was a "rule" or
  "skill" elsewhere may not be this repo's notion of the same word — see `global-rules` above vs.
  a path-scoped `rule`, or a skill's on-demand invocation vs. an agent's dedicated context scope).

If the specified/existing type doesn't match what the criteria point to, say so and propose the
right type before proceeding with the add.

## Writing components for the harness

Two properties of *how Claude Code loads a component* decide whether it's written well. Get
either wrong and the component either taxes every session or fails to fire when it should.

- **Match content depth to context cost.** As the type descriptions above note, a `rule` and
  `global-rules` load their *whole body* into the context of every session they apply to (a
  path-scoped rule whenever a matching file is touched, `global-rules` unconditionally), while a
  `skill`/`agent` body loads only when the component is invoked. Design to that: keep
  rule/`global-rules` bodies lean and operational — the standing constraint itself, nothing
  more. Do not add historical or rationale prose to them (what a rule was split out of, why it's
  shaped a certain way); that's a token cost paid on every session for information no one needs
  mid-task. A component's "why" — design trade-offs, deliberate-decision markers, gotchas —
  belongs in a `skill`/`agent` body, where it's free until triggered and sits at the decision
  point. Rationale that must be recorded but fits nowhere operational goes in a commit message or
  an ADR, never a rule body.
- **For an auto-invocable skill, the `description` is the trigger gate — not the body.** The
  `description` frontmatter is the text scanned to decide whether the skill fires; the body is
  read only *after* it fires. So a guard buried in the body ("only do this when X") cannot
  prevent a misfire — by then the skill is already chosen. Every auto-invocable skill's
  `description` therefore needs both its positive trigger phrases *and* explicit `Do NOT trigger`
  boundaries, and when you add or edit one, check its `description` against its siblings for
  trigger collisions — two skills that could both plausibly fire on the same request. A skill
  with `disable-model-invocation: true` fires only on an explicit `/name` and is exempt from all
  of this; it can't misfire.

## Adding/removing components

Adding or removing a top-level component is a single atomic change that touches all of:
- the component directory itself (its source file)
- its row in the root `README.md`'s component table
- its entry in `ALL_COMPONENTS` and its `is_known_component()` case in `components.sh`
- its `install_<name>()`/`uninstall_<name>()` function and dispatch case in both `install.sh` and
  `uninstall.sh`

Removing a component means removing it from *all* of those places in the same change — never
delete a component's directory while leaving it wired into `components.sh`/`install.sh`/
`uninstall.sh`/the root `README.md`. A dangling reference to a nonexistent component directory
breaks `install.sh all`/`uninstall.sh all` for everyone. Dry-run `install.sh`/`uninstall.sh`
(this repo's check, above) after any add/remove — it's what catches this drift.
