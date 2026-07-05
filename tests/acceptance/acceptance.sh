#!/usr/bin/env bash
# Black-box grader for fixtures/REQUIREMENTS.md. Invokes the produced software
# (todo.py) and asserts each requirement by observable behavior only:
# stdout/stderr, exit codes, and the state file. Never reads the implementation.
#
# Usage: acceptance.sh <workspace-dir>   (dir containing todo.py)
# Exit 0 iff every requirement passes.
set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <workspace-dir>" >&2
  exit 2
fi

# Resolve to an absolute path: todo() cd's into a fresh state dir before invoking
# the program, so a relative workspace path would no longer resolve from there.
if [[ ! -d "$1" ]]; then
  echo "acceptance: workspace '$1' is not a directory" >&2
  exit 2
fi
app="$(cd "$1" && pwd)/todo.py"
results=()
state_dirs=()
trap 'for d in "${state_dirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done' EXIT

# Each requirement is graded in its own fresh state directory so one failure
# can't cascade into the next check.
fresh() {
  state_dir="$(mktemp -d)"
  state_dirs+=("$state_dir")
}

# Run the software under test in the current state dir. stdin is /dev/null so
# an implementation that unexpectedly reads input fails fast instead of hanging.
todo() {
  (cd "$state_dir" && python3 "$app" "$@" </dev/null)
}

record() { # <id> <pass|FAIL> <description>
  results+=("$1|$2|$3")
}

# Tolerant number match: the id may be embedded in any phrasing, but must not
# be a digit-substring of a longer number.
has_number() { # <number> <<< text
  grep -Eq "(^|[^0-9])$1([^0-9]|$)"
}

grade() {
  if [[ ! -f "$app" ]]; then
    for r in add-prints-id list-shows-pending done-hides-completed \
             list-all-includes-completed state-persists-across-runs \
             unknown-id-fails-safely usage-on-bad-invocation; do
      record "$r" FAIL "todo.py not found in workspace"
    done
    return
  fi

  # add-prints-id — add prints the new item's id (first id is 1), exit 0
  fresh
  out="$(todo add "Buy milk" 2>/dev/null)"; rc=$?
  if [[ $rc -eq 0 ]] && has_number 1 <<<"$out"; then
    record add-prints-id pass "add records an item and prints its id"
  else
    record add-prints-id FAIL "add: exit=$rc output='$out' (expected exit 0 and id 1)"
  fi

  # list-shows-pending — list shows pending items with ids and text
  fresh
  todo add "Buy milk" >/dev/null 2>&1
  todo add "Walk dog" >/dev/null 2>&1
  out="$(todo list 2>/dev/null)"; rc=$?
  if [[ $rc -eq 0 ]] && grep -q "Buy milk" <<<"$out" && grep -q "Walk dog" <<<"$out" \
      && has_number 1 <<<"$out" && has_number 2 <<<"$out"; then
    record list-shows-pending pass "list shows pending items with ids"
  else
    record list-shows-pending FAIL "list: exit=$rc output='$out' (expected both items with ids 1 and 2)"
  fi

  # done-hides-completed — done removes the item from the pending list, exit 0
  fresh
  todo add "Buy milk" >/dev/null 2>&1
  todo done 1 >/dev/null 2>&1; rc=$?
  out="$(todo list 2>/dev/null)"
  if [[ $rc -eq 0 ]] && ! grep -q "Buy milk" <<<"$out"; then
    record done-hides-completed pass "done completes an item; it leaves the pending list"
  else
    record done-hides-completed FAIL "done 1: exit=$rc; list afterwards='$out' (item should be gone)"
  fi

  # list-all-includes-completed — list --all includes completed items; plain list does not
  fresh
  todo add "Alpha task" >/dev/null 2>&1
  todo add "Beta task" >/dev/null 2>&1
  todo done 1 >/dev/null 2>&1
  all_out="$(todo list --all 2>/dev/null)"; rc=$?
  pending_out="$(todo list 2>/dev/null)"
  if [[ $rc -eq 0 ]] && grep -q "Alpha task" <<<"$all_out" && grep -q "Beta task" <<<"$all_out" \
      && ! grep -q "Alpha task" <<<"$pending_out" && grep -q "Beta task" <<<"$pending_out"; then
    record list-all-includes-completed pass "list --all includes completed items"
  else
    record list-all-includes-completed FAIL "list --all='$all_out' list='$pending_out' (completed item only in --all)"
  fi

  # state-persists-across-runs — state survives separate process invocations, via todo.json in CWD
  fresh
  todo add "Persist me" >/dev/null 2>&1
  out="$(todo list 2>/dev/null)"
  if grep -q "Persist me" <<<"$out" && [[ -f "$state_dir/todo.json" ]]; then
    record state-persists-across-runs pass "state persists across invocations in ./todo.json"
  else
    record state-persists-across-runs FAIL "second process saw '$out'; todo.json present: $(test -f "$state_dir/todo.json" && echo yes || echo no)"
  fi

  # unknown-id-fails-safely — done on an unknown id: non-zero exit, message on stderr, state untouched
  fresh
  todo add "Keep me" >/dev/null 2>&1
  err="$(todo done 99 2>&1 >/dev/null)"; rc=$?
  out="$(todo list 2>/dev/null)"
  if [[ $rc -ne 0 ]] && [[ -n "$err" ]] && grep -q "Keep me" <<<"$out"; then
    record unknown-id-fails-safely pass "unknown id fails loudly without corrupting state"
  else
    record unknown-id-fails-safely FAIL "done 99: exit=$rc stderr='$err'; list='$out' (expected non-zero, stderr message, item intact)"
  fi

  # usage-on-bad-invocation — no args and unknown command both print usage and exit non-zero
  fresh
  out1="$(todo 2>&1)"; rc1=$?
  out2="$(todo frobnicate 2>&1)"; rc2=$?
  if [[ $rc1 -ne 0 ]] && grep -qi "usage" <<<"$out1" \
      && [[ $rc2 -ne 0 ]] && grep -qi "usage" <<<"$out2"; then
    record usage-on-bad-invocation pass "no args / unknown command print usage, exit non-zero"
  else
    record usage-on-bad-invocation FAIL "no-args: exit=$rc1 '$out1'; unknown: exit=$rc2 '$out2'"
  fi
}

grade

echo
echo "Requirement scorecard ($app):"
failures=0
for entry in "${results[@]}"; do
  id="${entry%%|*}"
  rest="${entry#*|}"
  status="${rest%%|*}"
  detail="${rest#*|}"
  if [[ "$status" == "pass" ]]; then
    printf '  [pass] %s — %s\n' "$id" "$detail"
  else
    printf '  [FAIL] %s — %s\n' "$id" "$detail"
    failures=$((failures + 1))
  fi
done
echo
total=${#results[@]}
echo "$((total - failures))/$total requirements satisfied."

[[ $failures -eq 0 ]]
