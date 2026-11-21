#!/usr/bin/env bash
# Install this bundle into ~/.claude.
#
# What this does that a plain `cp` does not:
#   - refuses to install a tree that fails check.sh;
#   - warns when the checkout is not on the default branch, since that installs unmerged config;
#   - backs up whatever is already there, before writing anything;
#   - removes files a previous install of THIS bundle put there and this one no longer has,
#     so deleting a rule from the repo actually deletes it from the machine;
#   - replaces only the top-level keys of settings.json that claude-settings/settings.json
#     declares, leaving every other key alone, and removes a key a previous install owned;
#   - lists every file it adds, edits or removes, and each settings key it changes, with the
#     device's value beside the bundle's, before it writes anything;
#   - reports rule files and skills it does not own, because two files disagreeing about the
#     same thing is worse than neither existing.
#
# Idempotent. `--dry-run` prints the plan and writes nothing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${CLAUDE_HOME:-$HOME/.claude}"
manifest="$dest/.claude-config-manifest"
# Lives beside the rules for editing, but installs as CLAUDE.md and never as a rule.
global_source="$here/claude-rules/global-rules.md"
settings_source="$here/claude-settings/settings.json"
statusline_source="$here/claude-settings/statusline.sh"
live_settings="$dest/settings.json"
# Separate from $manifest, whose every line is a path the prune step may `rm -rf`.
settings_manifest="$dest/.claude-config-settings-keys"
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

say() { printf '%s\n' "$*"; }
run() { if $dry_run; then say "  would: $*"; else "$@"; fi; }
in_list() { local needle="$1" item; shift; for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done; return 1; }

# Claude Code reads only `paths` from a rule's frontmatter. A rule with frontmatter but no
# `paths` key, or with frontmatter that never closes, loads in every session.
has_paths() {
  awk 'NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { closed = 1; exit }
       /^paths:/ { found = 1 }
       END { exit !(found && closed) }' "$1"
}

bundle_rules=()
for f in "$here/claude-rules/"*.md; do
  [[ "$f" == "$global_source" ]] || bundle_rules+=("$f")
done

# --- refuse a tree that fails its own checks ----------------------------------------------
if ! "$here/check.sh"; then
  say "check.sh failed; fix the bundle before installing"
  exit 1
fi

branch="$(git -C "$here" branch --show-current 2>/dev/null || true)"
default_branch="$(git -C "$here" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default_branch="${default_branch#origin/}"
default_branch="${default_branch:-main}"
if [[ -n "$branch" && "$branch" != "$default_branch" ]]; then
  say "warning: installing from '$branch', not '$default_branch' — every session gets unmerged config"
fi

# --- what this install will place, as paths relative to $dest -----------------------------
planned=("CLAUDE.md")
for f in "${bundle_rules[@]}"; do planned+=("rules/$(basename "$f")"); done
for d in "$here/claude-skills/"*/; do planned+=("skills/$(basename "$d")"); done
planned+=("statuslines/statusline.sh")

source_of() {
  case "$1" in
    CLAUDE.md) printf '%s' "$global_source" ;;
    rules/*) printf '%s' "$here/claude-rules/${1#rules/}" ;;
    skills/*) printf '%s' "$here/claude-skills/${1#skills/}" ;;
    statuslines/statusline.sh) printf '%s' "$statusline_source" ;;
  esac
}

added=()
edited=()
for path in "${planned[@]}"; do
  if [[ ! -e "$dest/$path" ]]; then
    added+=("$path")
  elif ! diff -rq "$(source_of "$path")" "$dest/$path" >/dev/null 2>&1; then
    edited+=("$path")
  fi
done

pruned=()
if [[ -f "$manifest" ]]; then
  while IFS= read -r old; do
    [[ -z "$old" ]] && continue
    in_list "$old" "${planned[@]}" && continue
    [[ -e "$dest/$old" ]] || continue
    pruned+=("$old")
  done < "$manifest"
fi

# --- settings.json: the keys this bundle owns ---------------------------------------------
# Each owned top-level key is replaced whole, so an entry added on the device and never
# committed here is dropped; the report below shows it before anything is written.
if ! command -v jq >/dev/null 2>&1; then
  say "jq is required to merge claude-settings/settings.json into $live_settings; install it and rerun"
  exit 1
fi

current='{}'
# A symlinked file (a dotfiles setup) would be replaced by a regular one on write, and `cp -p`
# would back up the link rather than its content.
for linked in "$live_settings" "$dest/statuslines/statusline.sh"; do
  if [[ -L "$linked" ]]; then
    say "$linked is a symlink; point CLAUDE_HOME at the real directory or replace the link, then rerun"
    exit 1
  fi
done
if [[ -e "$live_settings" ]]; then
  if ! current="$(jq -c . "$live_settings" 2>/dev/null)" || ! jq -e 'type == "object"' <<<"$current" >/dev/null; then
    say "$live_settings is not a JSON object; fix it by hand before installing"
    exit 1
  fi
fi

# statusLine.command is stored relative to the config directory, so the repo names no home
# directory and the same file installs for any user, CLAUDE_HOME included. Claude Code runs the
# command through a shell, so the absolute path is quoted.
quoted_dest="$(printf '%q' "$dest")"
want="$(jq -c --arg dest "$quoted_dest" \
  'if ((.statusLine? // {}) | .command? // "") != "" then .statusLine.command = ($dest + "/" + .statusLine.command) else . end' \
  "$settings_source")"

owned=()
while IFS= read -r key; do owned+=("$key"); done < <(jq -r 'keys_unsorted[]' <<<"$want")

dropped=()
if [[ -f "$settings_manifest" ]]; then
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    in_list "$key" "${owned[@]+"${owned[@]}"}" && continue
    jq -e --arg k "$key" 'has($k)' <<<"$current" >/dev/null && dropped+=("$key")
  done < "$settings_manifest"
fi

value_of() { jq -S --arg k "$2" '.[$k]' <<<"$1"; }

settings_added=()
settings_edited=()
for key in "${owned[@]}"; do
  if ! jq -e --arg k "$key" 'has($k)' <<<"$current" >/dev/null; then
    settings_added+=("$key")
  elif [[ "$(value_of "$current" "$key")" != "$(value_of "$want" "$key")" ]]; then
    settings_edited+=("$key")
  fi
done

merged="$(jq --argjson want "$want" '(reduce $ARGS.positional[] as $k (.; del(.[$k]))) + $want' \
  --args "${dropped[@]+"${dropped[@]}"}" <<<"$current")"

changes=$((${#added[@]} + ${#edited[@]} + ${#pruned[@]} + ${#settings_added[@]} + ${#settings_edited[@]} + ${#dropped[@]}))

# --- report every change before making it -------------------------------------------------
indent() { sed 's/^/      /'; }

if ((changes == 0)); then
  say "no changes: $dest already matches this bundle"
else
  $dry_run && say "would change in $dest:" || say "changing in $dest:"
  for path in "${added[@]+"${added[@]}"}"; do say "  added:   $path"; done
  for path in "${edited[@]+"${edited[@]}"}"; do say "  edited:  $path"; done
  for path in "${pruned[@]+"${pruned[@]}"}"; do say "  removed: $path (dropped from the bundle)"; done
  for key in "${settings_added[@]+"${settings_added[@]}"}"; do say "  settings.json: added .$key"; done
  for key in "${settings_edited[@]+"${settings_edited[@]}"}"; do
    # pluginConfigs holds a plugin's options, which can include sensitive values; the report
    # lands in scrollback and logs, so it names the key without printing either side.
    if [[ "$key" == pluginConfigs ]]; then
      say "  settings.json: edited .$key (values not shown)"
      continue
    fi
    say "  settings.json: edited .$key (- device, + bundle)"
    diff -u <(value_of "$current" "$key") <(value_of "$want" "$key") | tail -n +3 | indent || true
  done
  for key in "${dropped[@]+"${dropped[@]}"}"; do
    if [[ "$key" == pluginConfigs ]]; then
      say "  settings.json: removed .$key (values not shown)"
      continue
    fi
    say "  settings.json: removed .$key (dropped from the bundle; was:)"
    value_of "$current" "$key" | indent
  done
fi

# --- back up whatever is about to change --------------------------------------------------
# A rerun that changes nothing backs nothing up, or ~/.claude/.backups grows on every run.
existing=()
for path in "CLAUDE.md" "rules" "skills" "statuslines" "settings.json"; do
  [[ -e "$dest/$path" ]] && existing+=("$path")
done

if ((${#existing[@]})) && ((changes > 0)); then
  backup="$dest/.backups/$(date +%Y%m%d-%H%M%S)"
  say "backing up existing config to $backup"
  run mkdir -p "$backup"
  for path in "${existing[@]}"; do
    run cp -Rp "$dest/$path" "$backup/"
  done
fi

# --- install ------------------------------------------------------------------------------
for old in "${pruned[@]+"${pruned[@]}"}"; do run rm -rf "$dest/$old"; done

# A skill directory is replaced, not merged into: `cp -R` over an existing directory keeps
# any file the new version deleted.
run mkdir -p "$dest/rules" "$dest/skills" "$dest/statuslines"
run cp "$global_source" "$dest/CLAUDE.md"
for f in "${bundle_rules[@]}"; do run cp "$f" "$dest/rules/"; done
for d in "$here/claude-skills/"*/; do
  name="$(basename "$d")"
  run rm -rf "$dest/skills/$name"
  run cp -R "${d%/}" "$dest/skills/$name"
done
run cp "$statusline_source" "$dest/statuslines/statusline.sh"
run chmod +x "$dest/statuslines/statusline.sh"

# Written beside the target and renamed over it, so an interrupted run never leaves a
# truncated settings.json; 600 because the file also holds permissions and env.
if ((${#settings_added[@]} + ${#settings_edited[@]} + ${#dropped[@]})); then
  if $dry_run; then
    say "  would: write $live_settings"
  else
    tmp="$(mktemp "$dest/.settings.json.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    printf '%s\n' "$merged" > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$live_settings"
  fi
fi

if ! $dry_run; then
  printf '%s\n' "${planned[@]}" > "$manifest"
  printf '%s\n' "${owned[@]}" > "$settings_manifest"
fi

if $dry_run; then
  say "dry run: nothing written to $dest"
else
  say "installed to $dest: CLAUDE.md, $((${#planned[@]} - 1)) rules, skills and the status line, ${#owned[@]} settings keys"
fi

# --- rule files and skills this bundle does not own ----------------------------------------
# A rule with no `paths:` front matter loads in every session. Two of those covering the same
# ground is a contradiction nothing detects at runtime: the model just picks one. A foreign
# skill whose description overlaps one of these competes for the same trigger the same way.
# Anything pruned above is this bundle's own, even while a dry run leaves it in place.
foreign=()
for f in "$dest/rules/"*.md; do
  [[ -e "$f" ]] || continue
  name="$(basename "$f")"
  in_list "rules/$name" "${planned[@]}" "${pruned[@]+"${pruned[@]}"}" && continue
  foreign+=("$name")
done

foreign_always_on=()
if ((${#foreign[@]})); then
  say ""
  say "rules in $dest/rules this bundle does not own — check for overlap and delete the loser:"
  for name in "${foreign[@]}"; do
    if has_paths "$dest/rules/$name"; then
      say "  $name (path-scoped)"
    else
      say "  $name (always-on)"
      foreign_always_on+=("$dest/rules/$name")
    fi
  done
fi

foreign_skills=()
for d in "$dest/skills/"*/; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  in_list "skills/$name" "${planned[@]}" "${pruned[@]+"${pruned[@]}"}" && continue
  foreign_skills+=("$name")
done

if ((${#foreign_skills[@]})); then
  say ""
  say "skills in $dest/skills this bundle does not own — check each for overlap with this bundle's:"
  for name in "${foreign_skills[@]}"; do say "  $name"; done
fi

# --- the always-on budget, measured rather than written down -------------------------------
# CLAUDE.md and any rule without `paths:` front matter load in every session. This is the
# number worth watching, and README carries no copy of it, because a copy drifts. It counts
# what will load from $dest — including rules this bundle does not own, which is the case where
# a budget most often goes wrong.
always_on=("$global_source")
for f in "${bundle_rules[@]}"; do
  has_paths "$f" || always_on+=("$f")
done
always_on+=("${foreign_always_on[@]+"${foreign_always_on[@]}"}")

say ""
say "always-on: $(cat "${always_on[@]}" | wc -l | tr -d ' ') lines across ${#always_on[@]} files\
$( ((${#foreign_always_on[@]})) && printf ', %s of them not from this bundle' "${#foreign_always_on[@]}" )"

# --- commands this bundle names ------------------------------------------------------------
# Slash commands live in the REPL, not in `claude --help`, so there is no way to check them
# from a shell. Printing the list is honest; a check that always reports every command missing
# is a check that gets ignored.
#
# Front matter is stripped first: a `paths:` glob like "**/api/**" is not a command, and
# reporting it as one trains the reader to skim this list.
say ""
say "commands this bundle names — confirm each with /help in a new session:"
find "$here/claude-rules" "$here/claude-skills" -name '*.md' -exec \
  awk 'FNR==1 { infm = ($0 == "---") } infm { if (FNR > 1 && $0 == "---") infm = 0; next } { print }' {} + \
  | grep -oE '(^|[^A-Za-z0-9_/*">])/[a-z][a-z-]+' \
  | grep -oE '/[a-z][a-z-]+' | sort -u | sed 's/^/  /'
say "Delete any line naming a command the CLI does not have; it fails at the moment it is needed."

say ""
say "next: open a NEW session, then /context and /doctor"
