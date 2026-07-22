# claude

A composable library of personal Claude Code customizations. Each customization — a skill,
agent, or rule — lives in its own top-level directory with its source file, which doubles as
that component's documentation. `install.sh` copies the ones you want into `~/.claude/` (or
`$CLAUDE_CONFIG_DIR`, if set);
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
(`<path>.bak.<timestamp>`, or `~/.claude/.component-backups/` for directory-based components
like skills, so the backup itself is never mistaken for a live component), never silently
clobbered.

## Components

| Name | Type | Invocation | Installs to | What it does |
|---|---|---|---|---|
| [`write-prd`](write-prd) | skill | Auto-trigger or `/write-prd` | `~/.claude/skills/write-prd/` | Interviews you and writes a PRD at the start of a new project/feature |
| [`write-adr`](write-adr) | skill | Auto-trigger or `/write-adr` | `~/.claude/skills/write-adr/` | Writes a lightweight ADR for a significant decision |
| [`prepare-pr`](prepare-pr) | skill | `/prepare-pr` only | `~/.claude/skills/prepare-pr/` | Drafts a PR title/body against its bundled template, pushes, opens the PR, then runs an automatic post-open review |
| [`split-commits`](split-commits) | skill | Auto-trigger or `/split-commits` | `~/.claude/skills/split-commits/` | Splits a mixed working tree into atomic commits |
| [`device-logs`](device-logs) | skill | `/device-logs` only | `~/.claude/skills/device-logs/` | Captures console output from a wirelessly paired iOS device |
| [`port-ios-to-web`](port-ios-to-web) | skill | Auto-trigger or `/port-ios-to-web` | `~/.claude/skills/port-ios-to-web/` | Ports an iOS app to an equivalent web app |
| [`port-web-to-ios`](port-web-to-ios) | skill | Auto-trigger or `/port-web-to-ios` | `~/.claude/skills/port-web-to-ios/` | Ports a web app to an equivalent iOS app |
| [`doc-sync`](doc-sync) | skill | `/doc-sync` only | `~/.claude/skills/doc-sync/` | Audits docs against code for drift; reports or fixes (bundles its own explorer/planner/doc-writer/reviewer role-prompts) |
| [`session-handoff`](session-handoff) | skill | Auto-trigger or `/session-handoff` | `~/.claude/skills/session-handoff/` | Writes a session handoff doc, plus a harness-feedback doc (`~/.claude/harness-feedback/`) on what to keep/change about the Claude Code setup itself |
| [`component-review`](component-review) | skill | Auto-trigger or `/component-review` | `~/.claude/skills/component-review/` | Audits this repo's own components against `CLAUDE.md`'s type-decision and authoring conventions |
| [`ios-engineering`](ios-engineering) | skill | Auto-trigger or `/ios-engineering` | `~/.claude/skills/ios-engineering/` | Native iOS/Swift engineering: MVVM scaffolding, SwiftUI, Core Data, networking, concurrency, security, performance, testing (bundles 9 topic references) |
| [`harness-portability`](harness-portability) | skill | Auto-trigger or `/harness-portability` | `~/.claude/skills/harness-portability/` | Maps a component from another agent harness onto this repo's own type taxonomy and proposes/applies the port |
| [`issue-workplan`](issue-workplan) | skill | Auto-trigger or `/issue-workplan` | `~/.claude/skills/issue-workplan/` | Turns a group of GitHub issues into a self-contained workplan doc for a fresh/autonomous session to implement later |
| [`statusline`](statusline) | statusline | `/statusline` to select, then persists | `~/.claude/statuslines/statusline.sh` | Folder, git branch, model, effort, context bar, tokens, cache %, cost, rate limit |
| [`global-rules`](global-rules) | global-rules | Automatic, every session | `~/.claude/CLAUDE.md` | Personal cross-project defaults, loaded in every project on this machine |
| [`git-rules`](git-rules) | rule | Automatic, every session | `~/.claude/rules/git-rules.md` | Personal git/version-control conventions: commits, branches, worktrees, PR hygiene |
| [`swiftui-rules`](swiftui-rules) | rule | Automatic, when `**/*.swift` is touched | `~/.claude/rules/swiftui-rules.md` | SwiftUI `#Preview` conventions, scoped to `**/*.swift` so it's inert elsewhere |
| [`documentation-rules`](documentation-rules) | rule | Automatic, every session | `~/.claude/rules/documentation-rules.md` | Personal documentation conventions: ADRs, ticket/doc naming |

Two more component types are supported by `install.sh`/`uninstall.sh` but have no example yet:

| Type | Invocation | Source file | Installs to |
|---|---|---|---|
| slash command | `/<name>` only | `<name>/command.md` | `~/.claude/commands/<name>.md` |
| hook | Automatic, on its configured harness event | `<name>/hook.sh` + `<name>/hook.json` | `~/.claude/hooks/<name>.sh`, plus a merged entry under `~/.claude/settings.json`'s `.hooks.<event>` |
| output style | `/<name>` to select, then persists | `<name>/output-style.md` | `~/.claude/output-styles/<name>.md` |

## Using components in a session

Once installed to `~/.claude/` (or `$CLAUDE_CONFIG_DIR`), components activate the same way in
any stock Claude Code session — no project-level `.claude/` setup, hooks, or extra config
required. The component table's **Invocation** column is the source of truth for how to trigger
any given one; in general, by what that column says:

- **Automatic, every session** / **Automatic, when `<path>` is touched** — rules and
  global-rules. Nothing to type; the harness loads them for you.
- **Auto-trigger or `/<name>`** — most skills. Describe what you want in plain language (the
  "Triggers for" phrases in the skill's `description`) and the matching skill fires on its own,
  or invoke it directly.
- **`/<name>` only** — skills deliberately gated behind explicit invocation
  (`disable-model-invocation: true`) because the action is too consequential to fire without you
  naming it, and slash commands (no auto-trigger by design).
- **`/<name>` to select, then persists** — statuslines and output styles: pick once, active for
  the rest of the session without further invocation.
- **Spawned by Claude, never invoked directly** — agents (the `agent.md` extension point — no
  example component ships in this repo yet). Claude dispatches them via its own `Agent`/`Task`
  tool when a request matches their description, the same way built-in agents like `Explore` are
  spawned.
- **Automatic, on its configured harness event** — hooks (also no example yet); fire only when
  their event occurs (tool use, session stop, …), never from natural language.

Prefer the auto-triggering path where it exists: phrase requests the way a skill's
`description` expects (e.g. "write a PRD for X" for `write-prd`, "these are two different
changes, split them up" for `split-commits`) rather than memorizing slash names. If a skill
that should have fired didn't, check its `description` for the trigger phrases it actually
listens for — see "Writing components for the harness" in `CLAUDE.md` for why that field, not
the skill body, is what decides whether it activates.

## Adding a new component

1. Create `<name>/` with its source file (`SKILL.md`, `agent.md`, `rule.md`, `command.md`,
   `hook.sh` + `hook.json`, `output-style.md`, or `statusline.sh`). That file is the
   component's documentation as well as its implementation — capture any non-obvious "why"
   (design trade-offs, what it was split out of) in its own section rather than a separate doc.
2. Add a row to the component table above, including its **Invocation** cell (see "Using
   components in a session" above for the vocabulary to use).
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
