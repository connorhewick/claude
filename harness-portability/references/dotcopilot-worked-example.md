# Worked example: porting dotcopilot components

dotcopilot is a sibling repo targeting both Claude Code and GitHub Copilot from one source tree.
This is the first harness this skill's workflow was run against by hand, before the workflow was
encoded as a skill. Use this as a concrete before/after of steps 1-4 — not as a taxonomy to
assume applies to any other source harness.

## dotcopilot's cross-harness mechanics

dotcopilot writes to the lowest-common-denominator frontmatter for its two targets: no
`allowed-tools`/`disable-model-invocation`/`argument-hint` on the Claude Code side, no
Copilot-only fields either. Its installer is a dumb rsync/rename, not a content transform:

- `skills/<cat>/<name>/` → `~/.claude/skills/<name>/`
- `agents/*.agent.md` → `~/.claude/agents/*.md`
- `prompts/*.prompt.md` → `~/.claude/commands/*.prompt.md`
- `instructions/*.instructions.md` → `~/.claude/rules/`

That's the *simple* case — a straight copy works because both harnesses can read the same
lowest-common-denominator frontmatter. The *hard* case is when source and target aren't
LCD-compatible: this repo's own `doc-sync/SKILL.md` uses Claude-Code-only fields
(`allowed-tools`, `disable-model-invocation`, `argument-hint`) that a Copilot export would need
to strip, or that porting *into* Claude Code from a harness lacking them would need to add with
sensible defaults. Step 4 of this skill is where that stripping/adding gets decided per
component — don't assume a straight copy is ever safe without checking.

## Type-mismatch catalog (concrete instances of the general problem)

**dotcopilot's "agent" ≠ this repo's "agent".** dotcopilot's agent files (e.g.
`ios-engineer.agent.md`) are user-invoked skill-chain orchestrators — something a person runs
directly and that dispatches through a fixed sequence of other skills. This repo's `agent` type
is `Task`-spawned and context-isolated, never invoked directly by the user. The behavior dotcopilot
calls "agent" maps to this repo's `skill` instead. This branch acted on that finding directly:
`ios-engineer.agent.md`'s routing table became the entry point of this repo's new
`ios-engineering/SKILL.md`, with its 9 chained skills folded into `references/*.md` — following
the same bundling precedent `doc-sync` already established, rather than porting each chained
skill as its own flat top-level directory. (That flat-directory layout was the first draft of the
port and had to be caught and consolidated — worth avoiding that detour on the next port too.)

**dotcopilot's "prompt" mostly fails this repo's slash-command bar.** This repo's
`slash-command` type requires "no branching logic." Most of dotcopilot's prompts delegate to a
conditionally-branching agent/skill, so they fail that bar — only flat task-template prompts
(`show-config.prompt.md`-style, no delegation, no branching) are genuine slash-command
candidates here.

**dotcopilot's whole-project `*.instructions.md` templates have no equivalent type in this
repo's taxonomy.** Files like `python-project.instructions.md` look path-scoped like a `rule`
(they carry an `applyTo: "**/*.py"`-style scope declarator), but they're far too broad and
prescriptive to be one — closer to a project-type starter `CLAUDE.md` than a standing convention
for files already in an existing project. This repo's taxonomy has no slot for that category at
all; flag it as a genuine gap (step 3's "doesn't clearly fit any of the seven types" case) rather
than forcing it into `rule`.

## Takeaway

Three different outcomes from one source repo: a straight type remap (agent → skill, with
restructuring), a partial match requiring a stricter filter (prompt → slash-command, only some
qualify), and a genuine gap (instructions → nothing in this taxonomy). Expect all three when
scanning a new source harness — don't assume every component in a source catalog has a home
here.

## Export example (this repo → dotcopilot)

The false-cognate risk runs both ways. Consider exporting this repo's own `doc-sync` — a
`disable-model-invocation: true` skill that orchestrates four bundled role-prompts
(`explorer-agent.md`, `planner-agent.md`, `doc-writer-agent.md`, `reviewer-agent.md`) in sequence
via the `Agent` tool:

- **Frontmatter**: strip `disable-model-invocation`, `allowed-tools`, and `argument-hint` —
  Claude-Code-specific fields dotcopilot's own frontmatter has no equivalent for (per the
  lowest-common-denominator note above).
- **Type mapping, reversed**: `doc-sync` behaves like a fixed-sequence orchestrator dispatching
  through several sub-roles — exactly the shape the import catalog above identified as
  dotcopilot's own notion of "agent" (`ios-engineer.agent.md`), not dotcopilot's "skill". A naive
  export that keeps calling it a "skill" because that's what it's named here would carry the same
  false-cognate risk the import direction already ran into, just mirrored.
- **Bundling**: dotcopilot's `agents/*.agent.md` convention is a single file, not a directory with
  companion files — so the four role-prompts likely need folding into the one `.agent.md`'s own
  body (or dotcopilot's own equivalent of a routing table) rather than staying as separate bundled
  files, since that target harness may not support the same directory-of-companion-files pattern
  this repo's `references/*.md` convention relies on.

This is illustrative, not a confirmed dotcopilot spec — always verify the target harness's actual
bundling and frontmatter conventions in step 1 rather than assuming this example's specifics
transfer to a real export.
