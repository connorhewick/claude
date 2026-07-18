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
./install.sh all                  # install every component
./install.sh write-prd write-adr  # install just the named ones
./uninstall.sh write-prd         # remove just that one
./uninstall.sh all               # remove everything this repo installed
```

Re-running `install.sh` is safe — anything it would overwrite gets backed up first
(`<path>.bak.<timestamp>`), never silently clobbered.

## Components

| Name | Type | Installs to | What it does |
|---|---|---|---|
| [`write-prd`](write-prd) | skill | `~/.claude/skills/write-prd/` | Interviews you and writes a PRD at the start of a new project/feature |
| [`write-adr`](write-adr) | skill | `~/.claude/skills/write-adr/` | Writes a lightweight ADR for a significant decision |
| [`prepare-pr`](prepare-pr) | skill | `~/.claude/skills/prepare-pr/` | Reviews the diff and drafts a PR title/body |
| [`split-commits`](split-commits) | skill | `~/.claude/skills/split-commits/` | Splits a mixed working tree into atomic commits |
| [`device-logs`](device-logs) | skill | `~/.claude/skills/device-logs/` | Captures console output from a wirelessly paired iOS device |
| [`port-ios-to-web`](port-ios-to-web) | skill | `~/.claude/skills/port-ios-to-web/` | Ports an iOS app to an equivalent web app |
| [`port-web-to-ios`](port-web-to-ios) | skill | `~/.claude/skills/port-web-to-ios/` | Ports a web app to an equivalent iOS app |
| [`doc-sync`](doc-sync) | skill | `~/.claude/skills/doc-sync/` | Audits docs against code for drift; reports or fixes (bundles its own explorer/planner/doc-writer/reviewer role-prompts) |
| [`statusline`](statusline) | statusline | `~/.claude/statuslines/statusline.sh` | Folder, git branch, model, effort, context bar, tokens, cache %, cost, rate limit |
| [`global-rules`](global-rules) | global-rules | `~/.claude/CLAUDE.md` | Personal cross-project defaults, loaded in every project on this machine |

One more component type is supported by `install.sh`/`uninstall.sh` but has no example yet:

| Type | Source file | Installs to |
|---|---|---|
| slash command | `<name>/command.md` | `~/.claude/commands/<name>.md` |

## Adding a new component

1. Create `<name>/` with its source file (`SKILL.md`, `agent.md`, `rule.md`, `command.md`, or
   `statusline.sh`) and a `README.md`.
2. Add a row to the component table above.
3. Touch four things across `install.sh` / `uninstall.sh` (plus `components.sh`, shared by
   both):
   - `ALL_COMPONENTS` in `components.sh`
   - the `is_known_component()` case in `components.sh`
   - an `install_<name>()` / `uninstall_<name>()` function pair (one in each script — each just
     delegates to the typed helper in `common.sh` for its extension point)
   - the matching case in each script's `run_installer()` / `run_uninstaller()`

## Other things in this repo

- **`CLAUDE.md`** — this repo's own project instructions for anyone (human or Claude) working
  on it.
