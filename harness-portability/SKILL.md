---
name: harness-portability
description: >
  Map a component (or set of components) from another agent harness (GitHub Copilot, Cursor, a
  custom/homegrown agent config, dotcopilot, etc.) onto this repo's own component-type taxonomy
  (rule/skill/agent/global-rules/slash-command/hook/output-style), flag false-cognates where the
  source harness's own vocabulary doesn't line up with this repo's, and propose — then, on
  confirmation, apply — the concrete transform and wiring needed to install it here. Triggers
  for: "port this Cursor rule/Copilot skill/instructions file", "bring this <other harness>
  component into this repo", "map this component from another harness", "how would this become a
  skill/rule/agent here", "port dotcopilot's X". Do NOT trigger for porting a whole app between
  platforms (that's `port-ios-to-web`/`port-web-to-ios`), for auditing components already living
  in this repo (that's `component-review`), or for scaffolding an entirely new sibling repo's
  install/uninstall plumbing for another harness (a separate, not-yet-built skill covers that).
---

General-purpose harness-to-harness component porting. Given one or more components from another
agent harness, determine what each becomes in this repo's taxonomy and how to transform it —
grounded in this repo's own `CLAUDE.md`, not in any one source harness's assumptions.

This skill bundles one worked example, `references/dotcopilot-worked-example.md` — the concrete
type-mismatch catalog and cross-harness mechanics found the first time this workflow was run by
hand (porting dotcopilot components into this repo). Read it for a concrete before/after, not as
the source of truth for any harness other than dotcopilot — every other source harness needs its
own taxonomy detected fresh, per step 1.

## 1 — Identify the source

- Determine the source harness (its name, and where its components live — a repo path, a URL,
  pasted content).
- Determine the source harness's own type vocabulary: what categories of customization it has
  (e.g. "rule", "agent", "prompt", "instructions", "skill"), and for each, how it's triggered
  (explicit invocation, auto-match on phrasing, path-scoped, always-loaded, event-driven) and
  what scope it gets (isolated context? tool restrictions? whole-repo visibility?). Ask the user
  if this isn't already stated or evident from the source files — don't assume a source harness's
  type names mean what they sound like they mean.
- If the source harness is dotcopilot, read `references/dotcopilot-worked-example.md` first —
  its taxonomy and known mismatches are already catalogued there.

## 2 — Per component: detect trigger + scope

For each component to port, read its actual content and frontmatter (not just its source-harness
type label) and answer the same two questions `CLAUDE.md`'s "Choosing a component type" asks of a
new component originating in this repo:
- **What triggers it** — explicit invocation only, auto-match on phrasing, path/file-type match,
  a harness event, or unconditional load?
- **What scope does it need** — isolated context (spawned rather than run inline), tool-access
  restriction, or neither?

## 3 — Map to this repo's taxonomy

Read this repo's `CLAUDE.md` "Choosing a component type" section fresh — don't map from memory,
its criteria may have changed since this skill was written. For each component:

- Propose the target type (`rule`/`skill`/`agent`/`global-rules`/`slash-command`/`hook`/
  `output-style`) using the same criteria that section applies to a component originating here.
- **Flag false-cognates explicitly**: if the source harness's own label for this component (e.g.
  "agent", "prompt", "instructions") shares a name with one of this repo's types but the
  *behavior* doesn't match, say so by name rather than silently carrying the label over. (Example
  in the reference: dotcopilot's "agent" is a user-invoked skill-chain orchestrator; this repo's
  "agent" is `Task`-spawned and context-isolated — dotcopilot's maps to this repo's `skill`, not
  its `agent`.)
- If a component doesn't clearly fit any of the seven types, say so rather than forcing a fit —
  note it as a gap and stop there for that component.

## 4 — Propose the transform

For each component mapped in step 3, propose the concrete change needed to land it in this
repo's conventions:
- **Frontmatter**: fields to add (e.g. `disable-model-invocation`, `allowed-tools`,
  `argument-hint`, `paths`) or strip (source-harness-only fields with no equivalent here).
- **Content restructuring**: if the source component is really a chain of several source-harness
  sub-components (prompts, sub-agents), decide whether to bundle them as `references/*.md`/
  companion role-files under one router `SKILL.md` — follow the `doc-sync`/`ios-engineering`
  bundling precedent already established in this repo, rather than creating several flat
  top-level directories (a mistake documented in the reference file — avoid repeating it).
- **Naming**: whether the source name survives as-is or needs to change to fit this repo's
  naming conventions.
- Apply `CLAUDE.md`'s "Writing components for the harness" section here too: match content depth
  to context cost (`rule`/`global-rules` bodies stay lean; rationale/history goes in a skill
  body, commit message, or ADR instead — never in the ported component's own standing body), and
  for an auto-invocable skill, verify the proposed `description` carries both positive triggers
  and an explicit `Do NOT trigger` boundary against this repo's existing sibling skills.

## 5 — Report

Present one row per component, terse — `component-review`-style, not prose:

```
<source-name> (<source harness>'s <source type>)
  target type   : <type> | unclear — <why>
  false cognate : none | <source label> looks like this repo's <type> but isn't — <why>
  transform     : <frontmatter/content/naming changes needed, one line each>
```

Stop here and wait for confirmation before doing anything in step 6 — this is a proposal, not an
applied change.

## 6 — Execute (only after the user confirms)

For each component the user confirms:
1. Create the component's directory and source file per the proposed transform.
2. Apply this repo's own "Adding/removing components" checklist (`CLAUDE.md`): add a row to the
   root `README.md` table, add the component to `components.sh`'s `ALL_COMPONENTS` array and
   `is_known_component()` case, and add an `install_<name>()`/`uninstall_<name>()` function pair
   plus dispatch case to both `install.sh` and `uninstall.sh`.
3. Run this repo's dry-run install/uninstall check (its stated Definition of Done for this repo).
4. Recommend a `component-review` pass on the newly added component before calling the port done.

## Guardrails

- Never assume a source harness's type vocabulary maps 1:1 onto this repo's — check behavior,
  not names.
- Don't port a component whose target type is genuinely unclear (step 3) — surface the gap
  instead of guessing.
- Don't skip step 5's stop-and-confirm gate — porting a component adds new standing behavior to
  every session on this machine (if `rule`/`global-rules`) or new auto-trigger surface (if
  `skill`), which is worth a deliberate look before it's wired in.
- Scope is porting *named* components in, one or a handful at a time — not scaffolding an entire
  new sibling repo's install/uninstall plumbing for a target harness (a different, not-yet-built
  skill's job).
