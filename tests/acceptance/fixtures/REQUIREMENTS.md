# Requirements: `todo` — a command-line todo tracker

I want a small tool to track todo items from my terminal. Nothing fancy — add things, see
what's pending, mark things done. It has to be reliable: I'll use it across many terminal
sessions, so nothing can get lost between runs.

## Constraints

- A single file, `todo.py`, at the project root, invoked as `python3 todo.py <command> ...`.
- Python 3 standard library only — I don't want to install anything.
- State lives in a JSON file named `todo.json` in the current working directory, so I can
  keep separate lists in separate directories.

## Requirements

- **add-prints-id.** `python3 todo.py add "Buy milk"` records a new pending item and prints
  the new item's id. Ids are positive integers assigned sequentially starting at 1. Exits 0.
- **list-shows-pending.** `python3 todo.py list` prints each pending item with its id and
  text, one per line. Completed items do not appear. Exits 0.
- **done-hides-completed.** `python3 todo.py done <id>` marks that item completed and exits 0.
  The item no longer appears in `list`.
- **list-all-includes-completed.** `python3 todo.py list --all` prints every item, pending and
  completed, with completed items visibly marked as done.
- **state-persists-across-runs.** Items added in one invocation are visible to later
  invocations — state genuinely survives the process exiting.
- **unknown-id-fails-safely.** `python3 todo.py done <id>` for an id that doesn't exist exits
  non-zero, prints an error message to stderr, and leaves existing items untouched.
- **usage-on-bad-invocation.** Running with no arguments, or with an unknown command, prints
  usage information (the word "usage" and the available commands) and exits non-zero.

## Definition of done

Working software that meets the requirements above, finished according to this project's own
engineering conventions — see `AGENTS.md` in this repository for what "done" means here.
