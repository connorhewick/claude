#!/usr/bin/env bash
# Stop hook: runs the verification contract and surfaces the result.
#
# Mode switch: reads $HARNESS_VERIFY_STOP_MODE ("advise" default | "block"),
# set in .claude/settings.json's env block — a separate switch from the Phase 4
# guardrail rollout mode, since verification gating "done" is a distinct
# decision from deterministic edit/bash guardrails.
#
# advise: verify's fail-closed result is reported to the user/Claude as
#   context, but the session is allowed to stop. This is the sane default
#   while verify.d/ is empty (Phase 5) — otherwise every session would be
#   permanently blocked from finishing pre-adapter.
# block: verify failing (including "absent" stages) denies stopping.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${HARNESS_VERIFY_STOP_MODE:-advise}"

# Consume stdin (Stop hook payload) without using it — verify takes no arguments.
cat >/dev/null

report="$("$root/.claude/verify" --json 2>&1)" && verify_status=0 || verify_status=$?

if [[ "$verify_status" -eq 0 ]]; then
  exit 0
fi

summary="verify: not all stages passed (mode=$mode). $report"

if [[ "$mode" == "block" ]]; then
  jq -n --arg ctx "$summary" '{
    "hookSpecificOutput": {
      "hookEventName": "Stop",
      "decision": "block",
      "additionalContext": $ctx
    }
  }'
else
  # Deliberately omit hookSpecificOutput.additionalContext here: that field is
  # documented as feedback for Claude to act on, which re-prompts a response —
  # and a re-prompted response that tries to stop again re-triggers this same
  # hook, looping forever. systemMessage alone is informational (shown to the
  # user) without soliciting another turn, which is what "advise, don't block"
  # actually requires.
  jq -n --arg msg "$summary" '{ "systemMessage": $msg }'
fi

exit 0
