#!/usr/bin/env bash
# PreToolUse hook on Edit|Write. Denies edits to paths marked read-only in
# .claude/rules/generated-paths.md (single source of truth for the glob list —
# do not duplicate the patterns here) and flags obvious hardcoded secrets.
#
# Rollout mode: reads $HARNESS_GUARDRAIL_MODE ("advisory" default | "blocking").
# Advisory: violations are reported but do not block (exit 1, non-blocking per
# the hooks exit-code contract). Blocking: violations deny the edit (exit 2).
# Flip the mode by editing HARNESS_GUARDRAIL_MODE in .claude/settings.json.
set -euo pipefail
shopt -s globstar nullglob

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${HARNESS_GUARDRAIL_MODE:-advisory}"

input="$(cat)"
file_path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
content="$(jq -r '.tool_input.content // .tool_input.new_string // empty' <<<"$input")"

violation=""

if [[ -n "$file_path" ]]; then
  rel_path="${file_path#"$root"/}"
  patterns_file="$root/.claude/rules/generated-paths.md"
  if [[ -f "$patterns_file" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      if [[ "$rel_path" == $pattern ]]; then
        violation="Edit denied: '$rel_path' matches a generated/vendored path ($pattern) — see .claude/rules/generated-paths.md"
        break
      fi
    done < <(sed -n '/^paths:/,/^---/p' "$patterns_file" | grep '^\s*- ' | sed -E 's/^\s*-\s*"?([^"]*)"?\s*$/\1/')
  fi
fi

if [[ -z "$violation" && -n "$content" ]]; then
  if grep -qE -- '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' <<<"$content"; then
    violation="Edit denied: content appears to contain a private key block"
  elif grep -qE -- 'AKIA[0-9A-Z]{16}' <<<"$content"; then
    violation="Edit denied: content appears to contain an AWS access key ID"
  elif grep -qE -- '(secret|token|password|api[_-]?key)["'"'"']?\s*[:=]\s*["'"'"'][A-Za-z0-9/+_=-]{16,}["'"'"']' <<<"$content"; then
    violation="Edit denied: content appears to contain a hardcoded secret/token/password"
  fi
fi

if [[ -n "$violation" ]]; then
  if [[ "$mode" == "blocking" ]]; then
    echo "$violation" >&2
    exit 2
  else
    echo "[advisory, not blocking — HARNESS_GUARDRAIL_MODE=advisory] $violation" >&2
    exit 1
  fi
fi

exit 0
