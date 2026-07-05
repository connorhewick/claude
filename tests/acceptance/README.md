# Harness acceptance test

An end-to-end test of what this harness is *for*. Every other check in this repo
(`VALIDATION.md`) proves the machinery works — hooks fire, `verify` fails closed, agents
respect tool scopes. This test proves the payoff: **given real user requirements, a session
running under this harness produces working software that satisfies them.**

## Table of Contents

- [How it works](#how-it-works)
- [Usage](#usage)
- [What gets graded](#what-gets-graded)
- [Reading the result](#reading-the-result)
- [Cost and safety](#cost-and-safety)
- [Files](#files)

## How it works

The "user" is a requirements document (`fixtures/REQUIREMENTS.md`) asking for a small but real
program: a command-line todo tracker. The system under test is a throwaway project with this
harness bootstrapped into it, driven by one headless Claude Code session. The verdict is
black-box: the grader runs the produced program and checks observable behavior — it never reads
the implementation source.

```
run.sh
  1. setup    mktemp workspace -> git init -> scripts/bootstrap.sh -> drop in REQUIREMENTS.md
  2. agent    claude -p "build what REQUIREMENTS.md describes; conventions in AGENTS.md"
  3. grade    acceptance.sh  -> invokes todo.py, asserts each requirement, prints a scorecard
  4. report   whether the session registered verify.d/ adapters (evidence, not the verdict)
```

## Usage

```bash
# Validate the grader against the known-good reference — no agent, no token cost.
tests/acceptance/run.sh --self-test

# Full run: bootstrap, drive a real headless session, grade what it builds.
tests/acceptance/run.sh

# Pass options through to the session (model choice, etc.).
E2E_CLAUDE_ARGS="--model claude-sonnet-5" tests/acceptance/run.sh

# Grade a workspace you built some other way (e.g. an interactive session).
tests/acceptance/run.sh --workspace /path/to/project

# Keep the temp workspace after a passing run to inspect what was built.
tests/acceptance/run.sh --keep
```

The grader alone can be pointed at any directory containing a `todo.py`:

```bash
tests/acceptance/acceptance.sh /path/to/project
```

## What gets graded

Each requirement is checked independently in its own fresh state directory, so one failure
never cascades into another:

| Check | Behavior asserted |
|---|---|
| `add-prints-id` | `add "text"` records an item and prints its id (ids start at 1); exit 0 |
| `list-shows-pending` | `list` shows pending items with ids and text |
| `done-hides-completed` | `done <id>` completes an item; it leaves the pending list |
| `list-all-includes-completed` | `list --all` includes completed items; plain `list` does not |
| `state-persists-across-runs` | State persists across separate process invocations, via `./todo.json` |
| `unknown-id-fails-safely` | `done` on an unknown id exits non-zero, writes to stderr, leaves state intact |
| `usage-on-bad-invocation` | No args / unknown command print usage and exit non-zero |

The grader is tolerant of cosmetic output variation (it greps for ids and text rather than
demanding exact formatting) but strict on behavior — exit codes, persistence, and stderr on
error are non-negotiable.

## Reading the result

`run.sh` ends with a scorecard and a single line:

- `RESULT: PASS` — the software met every requirement. A self-managed workspace is deleted
  unless you passed `--keep`.
- `RESULT: FAIL` — at least one requirement failed. The scorecard names which, and the
  workspace is always kept so you can inspect what the session actually built.

The "Harness evidence" block (whether the session registered `verify.d/` adapters and what
`.claude/verify --json` reports) is printed for insight only. It is intentionally **not** part
of the pass/fail verdict: this test measures whether the user got working software, which is a
separate question from whether the harness's own arbiter-of-done seam was wired up.

## Cost and safety

- A full run makes **one real headless Claude Code session** — it costs tokens and takes a few
  minutes. `--self-test` and `--workspace` cost nothing.
- The session runs with `--dangerously-skip-permissions`. That is acceptable **only** because
  it runs inside a freshly created `mktemp` directory containing nothing but the harness
  skeleton and the requirements file — there is no existing work to damage. Do not repoint this
  at a real project.

## Files

| File | Role |
|---|---|
| `run.sh` | Orchestrator: setup, agent run, grade, report |
| `acceptance.sh` | Black-box grader (seven behavior checks + scorecard); reusable on any `todo.py` |
| `fixtures/REQUIREMENTS.md` | The user-voice requirements handed to the session |
| `fixtures/reference/todo.py` | Known-good implementation, used only by `--self-test` |
