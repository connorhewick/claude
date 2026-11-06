#!/usr/bin/env bash
# Check this bundle for the drift nothing catches at runtime.
#
# A rule that points at a file, a section or a skill that no longer exists still loads; it just
# sends the model somewhere empty. Frontmatter Claude Code can't use still loads too — as an
# always-on rule. Each check below turns one of those silent failures into a red line here.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rules_dir="$here/claude-rules"
skills_dir="$here/claude-skills"
global_source="$rules_dir/global-rules.md"

failures=0
fail() { printf 'FAIL %s\n' "$*"; failures=$((failures + 1)); }
rel() { printf '%s' "${1#"$here/"}"; }

documents=("$here/README.md" "$here/CLAUDE.md" "$rules_dir/"*.md "$skills_dir/"*/SKILL.md)

# Prints the lines between the opening and closing `---`, or nothing when there is no frontmatter.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

has_closing_marker() {
  awk 'NR == 1 { next } $0 == "---" { found = 1; exit } END { exit !found }' "$1"
}

# A document as one line, so a reference wrapped across two lines is still one match.
flatten() { tr '\n' ' ' < "$1" | tr -s ' '; }

# --- rule frontmatter ---------------------------------------------------------------------
# `paths` is the only field Claude Code reads, and frontmatter it can't parse is ignored: either
# way the rule loads in every session, which is the expensive tier, without saying so.
for f in "$rules_dir/"*.md; do
  if [[ "$f" == "$global_source" ]]; then
    head -1 "$f" | grep -q '^---$' && fail "$(rel "$f"): installs as CLAUDE.md, must have no frontmatter"
    continue
  fi
  head -1 "$f" | grep -q '^---$' || continue
  has_closing_marker "$f" || { fail "$(rel "$f"): frontmatter never closes"; continue; }
  block="$(frontmatter "$f")"
  grep -q '^paths:$' <<<"$block" || fail "$(rel "$f"): frontmatter has no paths: list, so it loads every session"
  stray="$(grep -vE '^paths:$|^  - "[^"]+"$' <<<"$block" || true)"
  [[ -z "$stray" ]] || fail "$(rel "$f"): frontmatter line is not a quoted paths entry: $stray"
done

# --- file references ----------------------------------------------------------------------
# A bare name is a rule; a name with a directory is a repo path. These names belong to the
# platform or another project, not to this bundle.
external_names=" CLAUDE.md AGENTS.md README.md CHANGELOG.md SKILL.md MEMORY.md "
for doc in "${documents[@]}"; do
  [[ -f "$doc" ]] || continue
  while IFS= read -r ref; do
    ref="${ref//\`/}"
    if [[ "$ref" == */* ]]; then
      [[ -e "$here/$ref" ]] || fail "$(rel "$doc"): \`$ref\` does not exist"
    elif [[ "$external_names" != *" $ref "* ]]; then
      [[ -f "$rules_dir/$ref" ]] || fail "$(rel "$doc"): \`$ref\` is not a rule in claude-rules/"
    fi
  done < <(grep -oE '`[A-Za-z0-9_./-]+\.md`' "$doc" || true)
done

# --- skill references ---------------------------------------------------------------------
for doc in "${documents[@]}"; do
  [[ -f "$doc" ]] || continue
  while IFS= read -r name; do
    [[ -f "$skills_dir/$name/SKILL.md" ]] || fail "$(rel "$doc"): skill \`$name\` does not exist"
  done < <(flatten "$doc" \
    | grep -oE '`[a-z][a-z-]*` skill|`claude-skills/[a-z][a-z-]*`|`[a-z][a-z-]*` §' \
    | sed -E 's/^`(claude-skills\/)?//; s/`.*$//' | sort -u || true)
done

# --- section references -------------------------------------------------------------------
# Written `file` §Heading text. A number names whichever section is in that position today,
# so after a reorder it still resolves — to the wrong section. Headings only.
resolve_target() {
  case "$1" in
    CLAUDE.md)       printf '%s' "$global_source" ;;
    */*.md)          printf '%s' "$here/$1" ;;
    *.md)            printf '%s' "$rules_dir/$1" ;;
    claude-skills/*) printf '%s' "$here/$1/SKILL.md" ;;
    *)               printf '%s' "$skills_dir/$1/SKILL.md" ;;
  esac
}

for doc in "${documents[@]}"; do
  [[ -f "$doc" ]] || continue
  while IFS= read -r match; do
    target="${match#\`}"
    target="${target%%\`*}"
    section="${match#*§}"
    section="${section# }"
    if [[ "$section" =~ ^[0-9] ]]; then
      fail "$(rel "$doc"): \`$target\` §${section%% *} refers to a section by number; use its heading"
      continue
    fi
    file="$(resolve_target "$target")"
    [[ -f "$file" ]] || { fail "$(rel "$doc"): \`$target\` in a section reference does not exist"; continue; }
    resolved=false
    while IFS= read -r heading; do
      [[ -n "$heading" && "$section" == "$heading"* ]] && { resolved=true; break; }
    done < <(grep -E '^#{2,3} ' "$file" | sed -E 's/^#+ //; s/^[0-9]+\. //')
    $resolved || fail "$(rel "$doc"): \`$target\` has no heading that starts \"${section:0:40}\""
  done < <(flatten "$doc" | grep -oE '`[^`]+` §[^`]{1,80}' || true)
done

if ((failures)); then
  printf '\n%s check(s) failed\n' "$failures"
  exit 1
fi
printf 'check: ok (%s documents)\n' "${#documents[@]}"
