---
name: harness-portability
description: >
  Map a component between this repo and another agent harness (GitHub Copilot, Cursor, a
  custom/homegrown agent config, dotcopilot, etc.) — in either direction. Import: a component
  from another harness onto this repo's own component-type taxonomy (rule/skill/agent/
  global-rules/slash-command/hook/output-style). Export: a component already living in this repo
  onto another harness's own taxonomy. Either way, flags false-cognates where the two harnesses'
  vocabularies don't line up, and proposes — then, on confirmation, applies — the concrete
  transform. Triggers for: "port this Cursor rule/Copilot skill/instructions file", "bring this
  <other harness> component into this repo", "export write-adr for Cursor", "make this a
  Copilot-compatible skill", "how would this become a skill/rule/agent here", "port dotcopilot's
  X". Do NOT trigger for porting a whole app between platforms (that's `port-ios-to-web`/
  `port-web-to-ios`), for auditing components already living in this repo (that's
  `component-review`), or for scaffolding an entirely new sibling repo's install/uninstall
  plumbing for another harness (that's `harness-scaffold`).
---

General-purpose harness-to-harness component porting, in either direction. Given one or more
components, determine what each becomes in the *target* harness's taxonomy and how to transform
it — grounded in whichever harness's own conventions apply on that end, not in one side's
assumptions carrying over unchecked to the other.

This skill bundles one worked example, `references/dotcopilot-worked-example.md` — the concrete
type-mismatch catalog and cross-harness mechanics found the first time this workflow was run by
hand (porting dotcopilot components into this repo), plus a symmetric export example. Read it for
a concrete before/after, not as the source of truth for any harness other than dotcopilot — every
other harness needs its own taxonomy detected fresh, per step 1.

## 1 — Identify the direction and the other harness

- Determine the direction: **import** (a component from another harness → this repo) or
  **export** (a component already in this repo → another harness). Ask if it's not obvious from
  how the request is phrased.
- Determine the *other* harness — its name, where its components live or should land (a repo
  path, a URL, pasted content), and its own type vocabulary: what categories of customization it
  has (e.g. "rule", "agent", "prompt", "instructions", "skill"), how each triggers (explicit
  invocation, auto-match on phrasing, path-scoped, always-loaded, event-driven), and what scope
  each gets (isolated context? tool restrictions? whole-repo visibility?). Ask the user if this
  isn't already stated or evident from its own files — don't assume a harness's type names mean
  what they sound like they mean, regardless of which side of the port it's on.
- If the other harness is dotcopilot, read `references/dotcopilot-worked-example.md` first — its
  taxonomy and known mismatches (both directions) are already catalogued there.

## 2 — Per component: detect trigger + scope

For each component being ported, read its actual content and frontmatter (not just its
originating harness's type label) and answer the same two questions `CLAUDE.md`'s "Choosing a
component type" asks of a new component originating in this repo — the same lens applies
regardless of which harness the component is landing in:
- **What triggers it** — explicit invocation only, auto-match on phrasing, path/file-type match,
  a harness event, or unconditional load?
- **What scope does it need** — isolated context (spawned rather than run inline), tool-access
  restriction, or neither?

## 3 — Map to the target's taxonomy

Read the *target* harness's own type-decision criteria fresh — don't map from memory. For import,
that's this repo's `CLAUDE.md` "Choosing a component type" section (its criteria may have changed
since this skill was written). For export, that's the other harness's own vocabulary and rules,
gathered in step 1. For each component:

- Propose the target type using the target harness's own criteria — this repo's seven types
  (`rule`/`skill`/`agent`/`global-rules`/`slash-command`/`hook`/`output-style`) for import, the
  other harness's own categories for export.
- **Flag false-cognates explicitly**: if a type label is shared between the two harnesses but the
  *behavior* doesn't match, say so by name rather than silently carrying the label over — this
  risk runs both ways. (Import example in the reference: dotcopilot's "agent" is a user-invoked
  skill-chain orchestrator; this repo's "agent" is `Task`-spawned and context-isolated —
  dotcopilot's maps to this repo's `skill`, not its `agent`. The same mismatch could just as
  easily bite on export.)
- If a component doesn't clearly fit any of the target's types, say so rather than forcing a fit —
  note it as a gap and stop there for that component.

## 4 — Propose the transform

For each component mapped in step 3, propose the concrete change needed to land it in the
target's conventions:
- **Frontmatter**: fields to add or strip. For import, this usually means adding Claude-Code
  fields (`disable-model-invocation`, `allowed-tools`, `argument-hint`, `paths`) a source harness
  never had. For export, it usually means the reverse — stripping those same Claude-Code-specific
  fields, since most other harnesses have no equivalent (see the reference's
  lowest-common-denominator note), and adding whatever the target harness's own convention needs.
- **Content restructuring**: if the component is really a chain of several sub-components
  (prompts, sub-agents), decide whether to bundle them as companion files under one router —
  follow the `doc-sync`/`ios-engineering` bundling precedent for import; for export, use whatever
  bundling mechanism the target harness itself actually supports, rather than assuming it has an
  equivalent to this repo's `references/*.md` pattern.
- **Naming**: whether the name survives as-is or needs to change to fit the target's conventions.
- Match verbosity to when the content loads and make sure an auto-triggered component's trigger
  gate is unambiguous — the same two principles `CLAUDE.md`'s "Writing components for the
  harness" section applies to this repo. For import, apply that section directly. For export,
  translate the same principles to the target harness's own loading model (gathered in step 1)
  — don't assume Claude Code's specific mechanics (`disable-model-invocation`, description-as-
  trigger-gate) carry over verbatim to a harness that works differently.

## 5 — Report

Present one row per component, terse — `component-review`-style, not prose:

```
<component-name> (<harness>'s <type>) — <import|export>
  target type   : <type> | unclear — <why>
  false cognate : none | <label> looks like the other harness's <type> but isn't — <why>
  transform     : <frontmatter/content/naming changes needed, one line each>
```

Stop here and wait for confirmation before doing anything in step 6 — this is a proposal, not an
applied change.

## 6 — Execute (only after the user confirms)

For each component the user confirms:

**Import** (landing in this repo):
1. Create the component's directory and source file per the proposed transform.
2. Apply this repo's own "Adding/removing components" checklist (`CLAUDE.md`): add a row to the
   root `README.md` table (including its Invocation cell), add the component to `components.sh`'s
   `ALL_COMPONENTS` array and `is_known_component()` case, and add an
   `install_<name>()`/`uninstall_<name>()` function pair plus dispatch case to both `install.sh`
   and `uninstall.sh`.
3. Run this repo's dry-run install/uninstall check (its stated Definition of Done for this repo).
4. Recommend a `component-review` pass on the newly added component before calling the port done.

**Export** (landing in another harness):
1. Write the transformed component file at the location identified in step 1 (the target repo's
   own component path/convention).
2. If the target repo has no install/uninstall plumbing of its own yet, stop here and point the
   user at `harness-scaffold` instead — standing up that plumbing is a structural bootstrapping
   job, not this skill's. This repo's own wiring/dry-run steps (above) don't apply outside this
   repo — don't try to improvise ad hoc equivalents for the target harness.

## Guardrails

- Never assume a type vocabulary maps 1:1 between harnesses in either direction — check behavior,
  not names.
- Don't port a component whose target type is genuinely unclear (step 3) — surface the gap
  instead of guessing.
- Don't skip step 5's stop-and-confirm gate — porting a component adds new standing behavior to
  every session that loads it (if `rule`/`global-rules`/import) or new auto-trigger surface (if
  `skill`), which is worth a deliberate look before it's wired in.
- Scope is porting *named* components, one or a handful at a time — not scaffolding an entire
  sibling repo's install/uninstall plumbing for a target harness (`harness-scaffold`'s job), and
  not porting a whole application between platforms (`port-ios-to-web`/`port-web-to-ios`'s job).
