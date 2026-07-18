# claude

A composable library of personal Claude Code customizations. Each customization — a skill,
agent, or rule — lives in its own top-level directory with its source file and a `README.md`.
`install.sh` copies the ones you want into `~/.claude/` (or `$CLAUDE_CONFIG_DIR`, if set);
`uninstall.sh` removes exactly what was installed.

This is a personal config repo, not a team-distributed product — there's no plugin marketplace,
no verification contract, no project-vendoring bootstrap script. If you fork it, everything here
installs globally, across every project on your machine.

## Quickstart

```
./install.sh all                 # install every component
./install.sh write-prd planner   # install just the named ones
./uninstall.sh write-prd         # remove just that one
./uninstall.sh all               # remove everything this repo installed
```

Re-running `install.sh` is safe — anything it would overwrite gets backed up first
(`<path>.bak.<timestamp>`), never silently clobbered.

## Components

| Name | Type | Installs to | What it does |
|---|---|---|---|
| [`write-prd`](write-prd) | skill | `~/.claude/skills/write-prd/` | Interviews you and writes a PRD at the start of a new project/feature |
| [`spec-first-planning`](spec-first-planning) | skill | `~/.claude/skills/spec-first-planning/` | Turns a goal into a spec + checklist before implementation |
| [`write-adr`](write-adr) | skill | `~/.claude/skills/write-adr/` | Writes a lightweight ADR for a significant decision |
| [`prepare-pr`](prepare-pr) | skill | `~/.claude/skills/prepare-pr/` | Reviews the diff and drafts a PR title/body |
| [`split-commits`](split-commits) | skill | `~/.claude/skills/split-commits/` | Splits a mixed working tree into atomic commits |
| [`device-logs`](device-logs) | skill | `~/.claude/skills/device-logs/` | Captures console output from a wirelessly paired iOS device |
| [`port-ios-to-web`](port-ios-to-web) | skill | `~/.claude/skills/port-ios-to-web/` | Ports an iOS app to an equivalent web app |
| [`port-web-to-ios`](port-web-to-ios) | skill | `~/.claude/skills/port-web-to-ios/` | Ports a web app to an equivalent iOS app |
| [`doc-sync`](doc-sync) | skill | `~/.claude/skills/doc-sync/` | Audits docs against code for drift; reports or fixes (needs `explorer`/`planner`/`doc-writer`/`reviewer`) |
| [`planner`](planner) | agent | `~/.claude/agents/planner.md` | Read-only: turns a goal into a plan |
| [`explorer`](explorer) | agent | `~/.claude/agents/explorer.md` | Read-only: open-ended codebase investigation |
| [`reviewer`](reviewer) | agent | `~/.claude/agents/reviewer.md` | Read-only: reviews a diff against stated conventions |
| [`doc-writer`](doc-writer) | agent | `~/.claude/agents/doc-writer.md` | Keeps README/ADRs/changelog-style docs current |
| [`docs`](docs) | rule | `~/.claude/rules/docs.md` | Path-scoped: ADR convention for `docs/**`, `**/*.md` |
| [`walkthroughs`](walkthroughs) | rule | `~/.claude/rules/walkthroughs.md` | Runs queued PR walkthroughs from a `claude-memory` branch (needs companion automation — see its README) |
| [`statusline`](statusline) | statusline | `~/.claude/statuslines/statusline.sh` | Folder, git branch, model, effort, context bar, tokens, cache %, cost, rate limit |

One more component type is supported by `install.sh`/`uninstall.sh` but has no example yet:

| Type | Source file | Installs to |
|---|---|---|
| slash command | `<name>/command.md` | `~/.claude/commands/<name>.md` |

## Adding a new component

1. Create `<name>/` with its source file (`SKILL.md`, `agent.md`, `rule.md`, `command.md`, or
   `statusline.sh`) and a `README.md`.
2. Add a row to the component table above.
3. Touch four things across `install.sh` / `uninstall.sh` (plus `lib/components.sh`, shared by
   both):
   - `ALL_COMPONENTS` in `lib/components.sh`
   - the `is_known_component()` case in `lib/components.sh`
   - an `install_<name>()` / `uninstall_<name>()` function pair (one in each script — each just
     delegates to the typed helper in `lib/common.sh` for its extension point)
   - the matching case in each script's `run_installer()` / `run_uninstaller()`

## Other things in this repo

- **`templates/global-CLAUDE.md` + `scripts/install-global.sh`** — installs a personal
  `~/.claude/CLAUDE.md`. Kept as its own small script rather than folded into `install.sh`,
  since `CLAUDE.md` is a single well-known file, not one of the component types above.
- **`scripts/init-claude-memory.sh`** and `.github/workflows/claude-pr-review.yml` — the
  companion automation the `walkthroughs` rule depends on (see its README).
- **`CLAUDE.md`** — this repo's own project instructions for anyone (human or Claude) working
  on it. `DECISIONS.md` is an append-only log of notable decisions made while building it.
