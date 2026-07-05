#!/usr/bin/env bash
# Vendors this harness's full skeleton into a target project — the fallback
# distribution path alongside the plugin+marketplace mechanism. Unlike the
# plugin (skills/agents/guardrail-hooks only), this copies everything,
# including .claude/verify, .claude/verify.d/, .claude/CONTRACT.md, and
# .claude/rules/ — since a project taking this path gets its own copy to
# adapt (register its own verify.d/ adapters, customize its own rules), not a
# centrally-updated install.
#
# Usage: scripts/bootstrap.sh <target-project-dir>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <target-project-dir>" >&2
  exit 1
fi

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$1"

if [[ ! -d "$dest" ]]; then
  echo "bootstrap: target directory '$dest' does not exist" >&2
  exit 1
fi

if [[ -e "$dest/.claude" || -e "$dest/AGENTS.md" || -e "$dest/CLAUDE.md" ]]; then
  echo "bootstrap: '$dest' already has .claude/, AGENTS.md, or CLAUDE.md — refusing to overwrite. Remove or merge manually." >&2
  exit 1
fi

mkdir -p "$dest/.claude"
cp -r "$src/.claude/." "$dest/.claude/"
rm -rf "$dest/.claude/scripts" 2>/dev/null || true  # this harness's own build tooling, not part of the vendored skeleton
rm -f "$dest/.claude/settings.local.json" 2>/dev/null || true  # this session's personal/local settings, never vendored
cp "$src/AGENTS.md" "$dest/AGENTS.md"
cp "$src/CLAUDE.md" "$dest/CLAUDE.md"
[[ -f "$src/.mcp.json" ]] && cp "$src/.mcp.json" "$dest/.mcp.json"

# Git hooks (pre-push doc-sync gate) live outside .claude/, so copy them
# explicitly. They are inert until core.hooksPath points at them.
if [[ -d "$src/.githooks" ]]; then
  cp -r "$src/.githooks" "$dest/.githooks"
  chmod +x "$dest"/.githooks/* 2>/dev/null || true
fi

chmod +x "$dest/.claude/verify" "$dest"/.claude/hooks/*.sh 2>/dev/null || true

# Enable the tracked hooks if the target is a git repo — but never clobber an
# existing custom hooksPath (husky, etc.).
if [[ -d "$dest/.githooks" ]] && git -C "$dest" rev-parse --git-dir >/dev/null 2>&1; then
  existing="$(git -C "$dest" config --get core.hooksPath || true)"
  if [[ -z "$existing" ]]; then
    git -C "$dest" config core.hooksPath .githooks
    echo "Enabled the pre-push doc-sync gate (core.hooksPath=.githooks) in $dest."
  else
    echo "Note: $dest already sets core.hooksPath='$existing'; left as-is."
    echo "  Chain .githooks/pre-push in manually to enable the doc-sync gate."
  fi
fi

echo "Vendored the harness skeleton into $dest."
echo "Next steps: review AGENTS.md/.claude/rules for project-specific customization,"
echo "register verify.d/ adapters for this project's stack, and run '$dest/.claude/verify' to confirm it fails closed as expected."
