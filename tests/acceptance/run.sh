#!/usr/bin/env bash
# End-to-end acceptance test for the harness itself: given real user requirements,
# does a session running under this harness produce WORKING software?
#
# Flow: bootstrap the harness into a throwaway project -> hand a headless Claude
# Code session the requirements -> grade the produced software black-box
# (acceptance.sh). The verdict is behavioral: did the software satisfy the user?
# The harness's own verify stages are reported separately, as evidence only.
#
# Usage: tests/acceptance/run.sh [--self-test] [--workspace DIR] [--keep]
#   --self-test       grade the bundled reference implementation instead of
#                     running an agent (validates the grader; costs nothing)
#   --workspace DIR   grade an existing workspace (skip setup + agent run)
#   --keep            don't delete the temporary workspace on success
#   E2E_CLAUDE_ARGS   extra args appended to the headless claude invocation
#                     (e.g. E2E_CLAUDE_ARGS="--model claude-sonnet-5")
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

keep=0
self_test=0
workspace=""
owned_workspace=0   # did we create it (and may we delete it)?

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) keep=1; shift ;;
    --self-test) self_test=1; shift ;;
    --workspace)
      [[ $# -ge 2 ]] || { echo "run: --workspace requires a directory" >&2; exit 2; }
      workspace="$2"; shift 2 ;;
    *) echo "Usage: $0 [--self-test] [--workspace DIR] [--keep]" >&2; exit 2 ;;
  esac
done

if [[ $self_test -eq 1 && -n "$workspace" ]]; then
  echo "run: --self-test and --workspace are mutually exclusive" >&2
  exit 2
fi

if [[ $self_test -eq 1 ]]; then
  echo "== Self-test: grading the reference implementation (no agent run) =="
  workspace="$(mktemp -d)"
  owned_workspace=1
  cp "$here/fixtures/reference/todo.py" "$workspace/todo.py"
elif [[ -n "$workspace" ]]; then
  [[ -d "$workspace" ]] || { echo "run: workspace '$workspace' does not exist" >&2; exit 2; }
  echo "== Grading existing workspace: $workspace =="
else
  command -v claude >/dev/null || { echo "run: 'claude' CLI not found on PATH" >&2; exit 2; }

  workspace="$(mktemp -d)"
  owned_workspace=1
  echo "== Workspace: $workspace =="

  echo "== Setup: git init + bootstrap the harness =="
  git -C "$workspace" init -q
  "$repo_root/scripts/bootstrap.sh" "$workspace"
  cp "$here/fixtures/REQUIREMENTS.md" "$workspace/REQUIREMENTS.md"
  git -C "$workspace" add -A
  git -C "$workspace" -c user.name="acceptance-test" -c user.email="acceptance@test.local" \
    commit -qm "chore: bootstrap harness skeleton and user requirements"

  echo "== Agent run: headless Claude Code session (this costs tokens) =="
  # --dangerously-skip-permissions is acceptable only because the workspace is a
  # throwaway temp dir containing nothing but the skeleton and the requirements.
  # shellcheck disable=SC2086  # E2E_CLAUDE_ARGS is intentionally word-split
  (cd "$workspace" && claude -p \
    "Read REQUIREMENTS.md and build the software it describes. The project's engineering conventions are in AGENTS.md — follow them, including the definition of done." \
    --dangerously-skip-permissions ${E2E_CLAUDE_ARGS:-})
fi

echo "== Grading against the requirements (black-box) =="
verdict=0
"$here/acceptance.sh" "$workspace" || verdict=1

# Informational only: did the harness's arbiter-of-done seam get exercised?
# Deliberately not part of the verdict — the test is about satisfying the user,
# not about the harness's own checks.
if [[ -x "$workspace/.claude/verify" ]]; then
  echo
  echo "Harness evidence (informational, not part of the verdict):"
  adapters="$(ls "$workspace/.claude/verify.d" 2>/dev/null || true)"
  if [[ -n "$adapters" ]]; then
    echo "  verify.d adapters registered by the session:" $adapters
  else
    echo "  verify.d adapters registered by the session: none"
  fi
  echo "  .claude/verify --json: $("$workspace/.claude/verify" --json all || true)"
fi

echo
if [[ $verdict -eq 0 ]]; then
  echo "RESULT: PASS — the produced software satisfies the user requirements."
  if [[ $owned_workspace -eq 1 && $keep -eq 0 ]]; then
    rm -rf "$workspace"
  else
    echo "Workspace kept at: $workspace"
  fi
else
  echo "RESULT: FAIL — see scorecard above."
  # Always keep a failing workspace: it's the evidence.
  echo "Workspace kept at: $workspace"
fi

exit "$verdict"
