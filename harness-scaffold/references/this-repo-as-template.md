# This repo's structure, as a template to adapt

The concrete pattern this skill generalizes from. Every piece below is Claude-Code-specific in
its details (the seven types, `~/.claude/`, `CLAUDE.md`) but the *shape* is what transfers to a
different target harness.

## 1 — Flat, one-directory-per-component root

No `src/` or category nesting. Each component's directory name is its identifier
(`write-adr/`, `doc-sync/`, `harness-portability/`). A component that needs supporting files
(bundled reference docs, role-prompts, scripts) keeps them inside its own directory —
`doc-sync/explorer-agent.md`, `ios-engineering/references/*.md` — never a separate top-level
directory per supporting file.

## 2 — Self-documenting components

Each directory's source file — `SKILL.md`, `agent.md`, `rule.md`, `command.md`, `hook.sh` +
`hook.json`, `output-style.md`, or `statusline.sh` for this repo's own seven types — *is* its own
documentation. No separate per-component `README.md`. A different target harness will have its
own file-naming convention per extension point; the principle that transfers is "the source file
doubles as the doc," not the specific filenames.

## 3 — A single manifest (`components.sh`)

```bash
ALL_COMPONENTS=(
  write-prd
  write-adr
  # ...one entry per component
)

is_known_component() {
  case "$1" in
    write-prd|write-adr|...)
      return 0 ;;
    *)
      return 1 ;;
  esac
}
```

Sourced by both `install.sh` and `uninstall.sh` — one array, not duplicated per script. A target
harness's equivalent just needs the same two things: an enumerable list of known components, and
a fast membership check both scripts can share.

## 4 — Symmetric install/uninstall scripts

Each component gets a one-line wrapper function delegating to a shared typed helper, keyed by
extension point (this repo's helpers live in `common.sh`):

```bash
# install.sh
install_write_adr() { install_skill write-adr; }
# uninstall.sh
uninstall_write_adr() { uninstall_skill write-adr; }
```

Plus a dispatch case in each script:

```bash
run_installer() {
  case "$1" in
    write-adr) install_write_adr ;;
    # ...
    *) echo "unknown component '$1'" >&2; exit 1 ;;
  esac
}
```

Both scripts accept `all` (every entry in `ALL_COMPONENTS`) or an explicit space-separated list.
For a target harness, the "one typed helper per extension point" idea is what transfers — e.g.
`install_skill()`/`install_rule()`/`install_agent()` here — not the specific helper names.

## 5 — Non-destructive reinstall

```bash
backup_if_exists() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  local backup="${2:-$target.bak.$(date +%Y%m%d%H%M%S)}"
  mkdir -p "$(dirname "$backup")"
  cp -r "$target" "$backup"
  echo "  backed up existing $target -> $backup"
}
```

Called before every overwrite. Directory-based components (skills) back up *outside* the
directory the harness scans for that type (`~/.claude/.component-backups/skills/<name>.bak.*`,
not a same-directory sibling) — a same-directory backup would itself be discovered as a second
live component. This same care applies to any target harness whose install directory is itself
scanned for active components.

## 6 — A root README component table

| Name | Type | Invocation | Installs to | What it does |
|---|---|---|---|---|

One row per component. **Invocation** states how it's triggered (auto-trigger, explicit-only,
automatic/path-scoped, event-driven, select-once-then-persists) — this repo learned the hard way
that leaving this out of the table and only describing it in prose creates a second,
hand-maintained list that drifts out of sync with the table itself. Build the target's table with
this column from the start.

## 7 — A root type-decision doc (`CLAUDE.md`-equivalent)

Not this repo's actual `CLAUDE.md` verbatim — its seven-type criteria are Claude-Code-specific —
but the same *shape* of guidance:
- How to decide a new component's type, from what triggers it and what scope it needs.
- A check for whether a request actually belongs in an existing component instead of a new one.
- What "adding/removing a component" requires touching (the manifest, the install/uninstall
  function pair + dispatch case, the README row) — stated as a single atomic checklist, the same
  way this repo's own "Adding/removing components" section is.

## 8 — Installs into a real config directory, env-var overridable

```bash
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
```

Lets a dry-run point at a scratch directory instead of the real one — this is what makes "dry-run
install/uninstall" a viable Definition of Done check rather than something that has to mutate a
real environment to verify. Any target harness's scaffold should have the equivalent override,
even if the target harness itself has no built-in notion of it.
