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
its own top-level directory with its source file and a `README.md`; there is no project-level
`.claude/agents`/`.claude/skills`/`.claude/rules` in this repo itself; developing the components
doesn't require having them installed.

## Adding/removing components

Adding or removing a top-level component is a single atomic change that touches all of:
- the component directory itself (source file + `README.md`)
- its row in `README.md`'s component table
- its entry in `ALL_COMPONENTS` and its `is_known_component()` case in `components.sh`
- its `install_<name>()`/`uninstall_<name>()` function and dispatch case in both `install.sh` and
  `uninstall.sh`

Removing a component means removing it from *all* of those places in the same change — never
delete a component's directory while leaving it wired into `components.sh`/`install.sh`/
`uninstall.sh`/`README.md`. A dangling reference to a nonexistent component directory breaks
`install.sh all`/`uninstall.sh all` for everyone. Dry-run `install.sh`/`uninstall.sh` (this repo's
check, above) after any add/remove — it's what catches this drift.
