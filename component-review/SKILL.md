---
name: component-review
description: >
  Audit this repo's own components (rule/skill/agent/global-rules/slash-command/hook/output-style)
  against `CLAUDE.md`'s "Choosing a component type" decision procedure, its
  "Writing components for the harness" authoring conventions, and the four-file wiring
  `components.sh`/`install.sh`/`uninstall.sh`/`README.md` requires. Triggers for: "review this
  repo's components", "audit my skills", "check this rule/skill/agent", "did I wire this
  component up right", or before/after adding or editing a component in this repo. Do NOT trigger
  for reviewing code *inside* an installed component's target project (SwiftUI code, git commits,
  etc) — that's the installed component's own job, not this one.
---

Audit one or more components in this repo (`/Users/connor/src/ai-configs/claude`, or wherever
this repo lives) against its own stated conventions. This is a conventions/wiring check, not a
prose or spelling review.

## 1 — Scope

- If the user names specific component(s), audit only those.
- If invoked with no target, default to whatever changed on the current branch:
  `git diff --name-only origin/main...HEAD -- '*/SKILL.md' 'rules/*.md' '*/agent.md' '*/command.md' '*/hook.json' '*/output-style.md' '*/global-rules'` (adjust the base branch if the repo's default isn't `main`), plus any new top-level directories.
- If the user explicitly asks for a full audit, read every row in the root `README.md`'s
  component table.

## 2 — Per component, check five things

Read the component's source file and `CLAUDE.md` in full before judging any of these — don't
audit from memory.

**a. Type choice.** Re-derive what type the component *should* be from `CLAUDE.md`'s "Choosing a
component type" criteria (what triggers it, what scope it needs) — don't take its current type at
face value. Flag a mismatch (e.g. something wired as an `agent` that's actually user-invoked, or a
new `rule` that duplicates ground `global-rules` already covers).

**b. Wiring completeness.** Per "Adding/removing components," a component must have all four:
a row in the root `README.md` table, an entry in `ALL_COMPONENTS` *and* a case in
`is_known_component()` (`components.sh`), and an `install_<name>()`/`uninstall_<name>()` function
pair with a dispatch case in both `install.sh` and `uninstall.sh`. Grep for the component's name
in all four files; flag any missing piece by name.

**c. Content depth vs. load cost** (only for `rule`/`global-rules`). These load their whole body
into every session they apply to. Flag historical or rationale prose (what it was split out of,
why it's shaped this way) that belongs in a `skill`/`agent` body, a commit message, or an ADR
instead — not in a body paid for on every session.

**d. Trigger gate quality** (only for a `skill` without `disable-model-invocation: true`). Its
`description` — not its body — decides whether it fires. Confirm the `description` has both
explicit positive trigger phrases and an explicit `Do NOT trigger` boundary. Then read every
sibling skill's `description` and flag any pair whose trigger phrases plausibly collide (both
could fire on a similar request) — name the two skills and the overlapping phrase.

**e. Technical currency.** Read the component's content looking for a specific external API,
library/framework version, platform/OS version, or tool behavior stated as a factual claim (a
named method, a version number, "as of X", a deprecated-vs-current framework idiom). Flag each as
a *candidate* needing re-verification against current standards — this check does not verify
currency itself (this skill's process is a local/static read, no web access), it only surfaces
what should get a dedicated look, the way a prior systematic pass already did for
`ios-engineering`'s reference files. Applies to any component, not just reference-heavy ones.

## 3 — Report

One verdict per component, terse — a plain pass/fail per checklist item, not an annotated copy of
the file:

```
<component-name> (<type>)
  type choice   : ok | should be <type> instead — <one-line why>
  wiring        : ok | missing: <README row | ALL_COMPONENTS | is_known_component | install fn | uninstall fn | dispatch case>
  content depth : ok | n/a | flagged: <what to move and where>
  trigger gate  : ok | n/a | flagged: <missing Do-NOT-trigger | collides with <other-skill> on "<phrase>">
  tech currency : ok | flagged: <claim + file:line>
```

End with a one-line overall summary ("N components reviewed, M clean, K with findings"). Do not
edit anything unless the user asks you to fix what you found — this skill reports, it doesn't
silently correct.
