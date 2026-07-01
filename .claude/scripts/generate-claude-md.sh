#!/usr/bin/env bash
# Regenerates CLAUDE.md from AGENTS.md (the source of truth).
# Run this after every edit to AGENTS.md. AGENTS.md is portable/tool-agnostic;
# CLAUDE.md is the Claude Code-specific always-on context file derived from it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
src="$root/AGENTS.md"
dst="$root/CLAUDE.md"

if [[ ! -f "$src" ]]; then
  echo "generate-claude-md: $src not found" >&2
  exit 1
fi

{
  echo "<!-- GENERATED FILE — do not edit. Source: AGENTS.md. Regenerate with .claude/scripts/generate-claude-md.sh -->"
  echo
  cat "$src"
} > "$dst"

echo "Regenerated $dst from $src"
