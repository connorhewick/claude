#!/usr/bin/env bash
# Installs templates/global-CLAUDE.md to the user's Claude Code config dir
# (~/.claude/CLAUDE.md, or $CLAUDE_CONFIG_DIR/CLAUDE.md if set). CLAUDE.md is a
# single well-known file, not one of the five component types install.sh/
# uninstall.sh dispatch over, so it keeps its own small standalone script.
#
# It never clobbers an existing global CLAUDE.md silently: any current file is
# backed up to a timestamped .bak beside it first, and if that backup can't be
# written the install aborts rather than overwrite.
#
# Usage: scripts/install-global.sh
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="$src/templates/global-CLAUDE.md"

if [[ ! -f "$template" ]]; then
  echo "install-global: template not found at $template" >&2
  exit 1
fi

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
target="$config_dir/CLAUDE.md"

mkdir -p "$config_dir"

if [[ -f "$target" ]]; then
  if cmp -s "$template" "$target"; then
    echo "install-global: $target is already up to date — nothing to do."
    exit 0
  fi
  backup="$target.bak.$(date +%Y%m%d%H%M%S)"
  # set -e aborts here if the backup can't be written, so we never overwrite
  # an existing global CLAUDE.md without first preserving it.
  cp "$target" "$backup"
  echo "Backed up existing global CLAUDE.md to $backup"
fi

cp "$template" "$target"
echo "Installed global CLAUDE.md to $target."
echo "Review it, then add any personal preferences below the marked line at the end."
