---
name: harness-scaffold
description: >
  Stand up this repo's own meta-architecture — a flat one-directory-per-component layout, a
  manifest of known components, symmetric install/uninstall scripts with non-destructive
  reinstall, a README component table, and a lightweight type-decision doc — for a *different*
  target harness, adapted to that harness's own extension points and install-directory
  convention. Works both for an existing ad hoc collection of another harness's customizations
  (restructured in place) and for a from-scratch request to start one. Triggers for: "make my
  Cursor config repo look like this one", "set up a component library for <harness>", "scaffold
  an install/uninstall system for my agent config", "give this repo the same structure as
  ai-configs/claude". Do NOT trigger for porting a single component's *content* between harnesses
  (that's `harness-portability` — this skill produces the empty-or-restructured container, not
  populated components), or for porting a whole application between platforms (that's
  `port-ios-to-web`/`port-web-to-ios`).
---

Replicate this repo's own structural pattern — not its content — onto a different target harness.
This skill produces the container: the manifest, the install/uninstall plumbing, the README
index, and a lightweight type-decision doc, adapted to whatever the target harness actually
supports. It does not decide what type any given existing component becomes, or write ported
component content — that's `harness-portability`'s job, run once per component after this
skill's scaffold exists.

This skill bundles `references/this-repo-as-template.md` — a structural summary of this repo's
own pattern plus concrete `components.sh`/`install.sh`/`uninstall.sh`/`common.sh` snippets to
adapt. Read it before proposing a scaffold; it's the concrete boilerplate this skill generalizes
from.

## 1 — Identify the target

- The target harness's name, and its repo: an existing path/URL with its own ad hoc
  customizations already in it, or an explicit "start fresh" request.
- The target harness's own install-directory convention — its equivalent of `~/.claude/` (and
  whether it supports an env-var override the way `$CLAUDE_CONFIG_DIR` does here). Ask if this
  isn't already known.

Ask for whatever isn't given rather than guessing — a scaffold built against the wrong install
path is dead on arrival.

## 2 — Inventory existing content, if any

If the target repo already has customizations, list what exists in *its own* current layout and
vocabulary — don't assign a this-repo-style type to any of it yet. That per-component type
decision belongs to `harness-portability`, run afterward, once the container this skill builds
actually exists to receive the result.

## 3 — Determine the target harness's own extension-point vocabulary

Ask rather than assume the target mirrors this repo's seven types (`rule`/`skill`/`agent`/
`global-rules`/`slash-command`/`hook`/`output-style`) — a different harness may have fewer
categories (e.g. only one flat "rule" concept), more, or differently-scoped ones. The scaffold's
manifest and install/uninstall dispatch need to be keyed to whatever the target harness actually
distinguishes, not this repo's own list.

## 4 — Propose the scaffold

Using `references/this-repo-as-template.md` as the concrete pattern to adapt, propose:

- **Directory layout**: one top-level directory per component, source file doubles as its own
  documentation — same flat shape, no `src/`/category nesting.
- **Manifest** (`components.sh`-equivalent): an array of known component names plus a
  known-component gate, keyed to the target's own extension points from step 3.
- **Install/uninstall scripts**: paired `install_<name>()`/`uninstall_<name>()` functions per
  component, dispatching through a shared typed-helper file (`common.sh`-equivalent) — one
  install/remove function pair per *extension point*, not per component, mirroring this repo's
  `install_skill`/`install_rule`/`install_agent`/etc. pattern.
- **Non-destructive reinstall**: port the backup-before-overwrite behavior
  (`backup_if_exists`-equivalent) so re-running install never silently clobbers.
- **README component table**: same columns this repo uses (Name, Type, Invocation, Installs to,
  What it does), populated from step 2's inventory or empty if starting fresh.
- **A lightweight type-decision doc** (this repo's `CLAUDE.md`-equivalent): the *shape* of the
  guidance — how to decide a new component's type from what triggers it and what scope it needs,
  and what "adding/removing a component" requires touching — adapted to the target's own
  extension points from step 3. Don't copy this repo's `CLAUDE.md` verbatim; its seven-type
  criteria are Claude-Code-specific.

Report the proposed layout — file by file — before creating anything.

## 5 — Stop and confirm

Wait for explicit confirmation before writing anything. Standing up install/uninstall plumbing in
a different repo (or creating one from scratch) is more consequential than editing the current
project — this mirrors `harness-portability`'s own execute-on-confirm gate, for the same reason.

## 6 — Execute (only after the user confirms)

- Create the proposed directory structure, manifest, scripts, README, and type-decision doc.
- If the target location is reachable and executable now, dry-run its install/uninstall (`all`
  and a single component) the same way this repo's own Definition of Done requires — don't just
  assert the scripts are correct, run them against a scratch destination.
- Hand off: recommend running `harness-portability` next, once per existing component identified
  in step 2, to actually populate the new scaffold with ported content.

## Guardrails

- Never assume the target harness's extension-point vocabulary mirrors this repo's seven types —
  confirm in step 3.
- Don't skip the step 5 confirm gate — this writes to a different repo/location, a bigger blast
  radius than the current project.
- This skill produces structure only. It does not map or port any individual component's
  content — that's `harness-portability`'s job, run after this skill's scaffold exists.
- If the target repo already has customizations, never discard them while restructuring — the
  inventory from step 2 must be preserved (even if left unconverted, pending
  `harness-portability`), not deleted in the course of laying down the new structure.
