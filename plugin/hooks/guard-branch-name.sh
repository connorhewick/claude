#!/usr/bin/env bash
# PreToolUse hook on Bash. Enforces the Phase 2 branch-naming scheme whenever a
# new branch is created: "<ticket-id>/<short-description>" (e.g. PROJ-123/add-login),
# falling back to "<type>/<short-description>" (feat|fix|chore|docs|refactor|test)
# when no ticket exists.
#
# Rollout mode: reads $HARNESS_GUARDRAIL_MODE ("advisory" default | "blocking").
# Flip via HARNESS_GUARDRAIL_MODE in .claude/settings.json.
set -euo pipefail

mode="${HARNESS_GUARDRAIL_MODE:-advisory}"
input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"

branch_name=""
if [[ "$command" =~ git[[:space:]]+checkout[[:space:]]+-b[[:space:]]+([^[:space:]]+) ]]; then
  branch_name="${BASH_REMATCH[1]}"
elif [[ "$command" =~ git[[:space:]]+switch[[:space:]]+-c[[:space:]]+([^[:space:]]+) ]]; then
  branch_name="${BASH_REMATCH[1]}"
elif [[ "$command" =~ git[[:space:]]+branch[[:space:]]+([^[:space:]-][^[:space:]]*) ]]; then
  branch_name="${BASH_REMATCH[1]}"
fi

[[ -z "$branch_name" ]] && exit 0

ticket_scheme='^[A-Za-z][A-Za-z0-9]*-[0-9]+/[a-z0-9][a-z0-9-]*$'
type_scheme='^(feat|fix|chore|docs|refactor|test)/[a-z0-9][a-z0-9-]*$'

if [[ "$branch_name" =~ $ticket_scheme || "$branch_name" =~ $type_scheme ]]; then
  exit 0
fi

violation="Branch name '$branch_name' doesn't match the required scheme: <TICKET-ID>/<short-description> (e.g. PROJ-123/add-login), or <type>/<short-description> with type in feat|fix|chore|docs|refactor|test when no ticket exists"

if [[ "$mode" == "blocking" ]]; then
  echo "$violation" >&2
  exit 2
else
  echo "[advisory, not blocking — HARNESS_GUARDRAIL_MODE=advisory] $violation" >&2
  exit 1
fi
