#!/usr/bin/env bash
# PreToolUse hook on Bash. Denies three hard-blocked command patterns:
# recursive force-delete, force-push to the default branch, and piping a
# remote script into a shell.
#
# Rollout mode: reads $HARNESS_GUARDRAIL_MODE ("advisory" default | "blocking").
# Advisory: violations are reported but do not block (exit 1). Blocking:
# violations deny the command (exit 2). Flip via HARNESS_GUARDRAIL_MODE in
# .claude/settings.json.
set -euo pipefail

mode="${HARNESS_GUARDRAIL_MODE:-advisory}"
input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"

violation=""

if [[ -z "$violation" ]] && grep -qE '\brm\b[^|;&]*(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\b|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\b|--recursive[^|;&]*--force\b|--force[^|;&]*--recursive\b)' <<<"$command"; then
  violation="Command denied: recursive force-delete (rm -rf or equivalent)"
fi

if [[ -z "$violation" ]] && grep -qE '\bgit\s+push\b.*(--force\b|--force-with-lease\b|(^|\s)-f(\s|$))' <<<"$command"; then
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  default_branch="${default_branch:-main}"
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  target_branch="$(grep -oE '(origin\s+|origin/)?[A-Za-z0-9._/-]+\s*$' <<<"$command" | tail -n1 | sed -E 's#^origin/?##' | xargs)"
  if [[ "$target_branch" == "$default_branch" ]] || { [[ -z "$target_branch" || "$target_branch" == "$command" ]] && [[ "$current_branch" == "$default_branch" ]]; }; then
    violation="Command denied: force-push to the default branch ($default_branch)"
  fi
fi

if [[ -z "$violation" ]] && grep -qE '\b(curl|wget)\b[^|;&]*\|[^|;&]*\b(sh|bash|zsh|sudo\s+sh|sudo\s+bash)\b' <<<"$command"; then
  violation="Command denied: piping a remote download into a shell"
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
