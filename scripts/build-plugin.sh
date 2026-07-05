#!/usr/bin/env bash
# Regenerates plugin/ from .claude/ — the plugin bundle for marketplace
# distribution. .claude/ is the single source of truth; never hand-edit
# plugin/, run this script after changing skills/, agents/, or the guardrail
# hook scripts.
#
# Deliberately NOT bundled into the plugin: .claude/verify, .claude/verify.d/,
# .claude/CONTRACT.md, .claude/rules/. These are per-project state (which
# stack adapters a specific project has registered, which paths a specific
# project protects) — they can't be meaningfully shared as plugin content.
# Projects that want the full skeleton, including those, use the bootstrap
# script (scripts/bootstrap.sh) instead, which vendors a full copy.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/plugin"
version="$(date +%Y.%-m.%-d)"

rm -rf "$dest"
mkdir -p "$dest/.claude-plugin" "$dest/skills" "$dest/agents" "$dest/hooks"

cp -r "$root/.claude/skills/." "$dest/skills/"
cp -r "$root/.claude/agents/." "$dest/agents/"
cp "$root/.claude/hooks/guard-edits.sh" "$root/.claude/hooks/guard-bash.sh" "$root/.claude/hooks/guard-branch-name.sh" "$dest/hooks/"
chmod +x "$dest"/hooks/*.sh

cat > "$dest/hooks/hooks.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/guard-edits.sh", "args": ["\${CLAUDE_PROJECT_DIR}"] }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/guard-bash.sh" },
          { "type": "command", "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/guard-branch-name.sh" }
        ]
      }
    ]
  }
}
EOF

cat > "$dest/.claude-plugin/plugin.json" <<EOF
{
  "name": "claude-code-harness",
  "description": "Language-agnostic Claude Code harness: guardrail hooks, orchestration subagents, and reusable skills. Verification contract and path rules are project-specific and ship via the bootstrap script instead — see README.",
  "version": "$version",
  "author": { "name": "Connor", "email": "connor@hewick.ca" },
  "repository": "https://github.com/connorhewick/claude"
}
EOF

echo "Built plugin/ at version $version from .claude/skills, .claude/agents, and the guardrail hooks."
