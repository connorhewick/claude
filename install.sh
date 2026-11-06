#!/usr/bin/env bash
# Install this bundle into ~/.claude.
#
# What this does that a plain `cp` does not:
#   - refuses to install a tree that fails check.sh;
#   - warns when the checkout is not on the default branch, since that installs unmerged config;
#   - backs up whatever is already there, before writing anything;
#   - removes files a previous install of THIS bundle put there and this one no longer has,
#     so deleting a rule from the repo actually deletes it from the machine;
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

# --- back up whatever is already there ----------------------------------------------------
# A rerun that changes nothing backs nothing up, or ~/.claude/.backups grows on every run.
up_to_date() {
  local f d old
  cmp -s "$global_source" "$dest/CLAUDE.md" || return 1
  for f in "${bundle_rules[@]}"; do cmp -s "$f" "$dest/rules/$(basename "$f")" || return 1; done
  for d in "$here/claude-skills/"*/; do
    diff -rq "${d%/}" "$dest/skills/$(basename "$d")" >/dev/null 2>&1 || return 1
  done
  if [[ -f "$manifest" ]]; then
    while IFS= read -r old; do
      [[ -z "$old" ]] || in_list "$old" "${planned[@]}" || [[ ! -e "$dest/$old" ]] || return 1
    done < "$manifest"
  fi
}

existing=()
for path in "CLAUDE.md" "rules" "skills"; do
  [[ -e "$dest/$path" ]] && existing+=("$path")
done

if ((${#existing[@]})) && ! up_to_date; then
  backup="$dest/.backups/$(date +%Y%m%d-%H%M%S)"
  say "backing up existing config to $backup"
  run mkdir -p "$backup"
  for path in "${existing[@]}"; do
    run cp -R "$dest/$path" "$backup/"
  done
fi

# --- remove what a previous install of this bundle left behind and this one drops ----------
pruned=()
if [[ -f "$manifest" ]]; then
  while IFS= read -r old; do
    [[ -z "$old" ]] && continue
    in_list "$old" "${planned[@]}" && continue
    [[ -e "$dest/$old" ]] || continue
    say "removing (dropped from the bundle): $old"
    run rm -rf "$dest/$old"
    pruned+=("$old")
  done < "$manifest"
fi

# --- install ------------------------------------------------------------------------------
# A skill directory is replaced, not merged into: `cp -R` over an existing directory keeps
# any file the new version deleted.
run mkdir -p "$dest/rules" "$dest/skills"
run cp "$global_source" "$dest/CLAUDE.md"
for f in "${bundle_rules[@]}"; do run cp "$f" "$dest/rules/"; done
for d in "$here/claude-skills/"*/; do
  name="$(basename "$d")"
  run rm -rf "$dest/skills/$name"
  run cp -R "${d%/}" "$dest/skills/$name"
done
$dry_run || printf '%s\n' "${planned[@]}" > "$manifest"

say "installed to $dest: CLAUDE.md, $((${#planned[@]} - 1)) rules and skills"

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
