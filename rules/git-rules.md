# Version control

- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, …) for
  every commit message. Never commit or push unless asked.
- When changes span more than one distinct concern, split them into separate, logical, atomic
  commits rather than one mixed commit (the `split-commits` skill / `/split-commits`) — present
  the split as a plan and get approval before committing.
- Start new feature work on its own feature branch, created before the first edit — not
  deferred until commit time. If you're on the default branch and about to make a non-trivial
  change, branch immediately, even before exploring or editing; don't let edits accumulate on
  `main`'s working tree first and branch only when a commit tool's precondition check catches
  it. A dirty default-branch working tree blocks any other session sharing that checkout from
  cleanly branching off `main` for its own task in the meantime.
- When starting a new, distinct task, always branch off `main` (or whatever branch the user
  specifies) rather than continuing on top of whatever branch happens to be checked out — even
  if that's a feature branch left over from earlier work in the session. Each distinct task gets
  its own branch off the right base, not piled onto an unrelated one.
- Give every branch a descriptive name that identifies the feature or work item, following this
  repo's existing convention (`feat/coding-rules-solid-dry`, `fix/issue-53-device-logs-auto-invoke`)
  — never an opaque default like `worktree-1` that tells a reader nothing about what's on it.
- When a branch/task is opened to work a GitHub issue, assign that issue to yourself
  (`gh issue edit <number> --add-assignee @me`) as part of creating the branch, not as an
  afterthought once work is already underway.
- Before the first edit in any new session, check `git status`/`git branch --show-current`. If
  the working tree already has uncommitted changes or sits on a branch unrelated to the task at
  hand, treat that as another session's in-progress work, not something safe to build on top of,
  stash, or switch away from — start the new task in its own git worktree
  (`EnterWorktree`/`ExitWorktree`) instead of editing the shared checkout. Do this even if this
  is the session's very first action: a fresh session has no memory of what else may already be
  running against the same checkout, so opening a new terminal tab and starting a new task must
  never risk interfering with work already in progress there. **Unless the project's own
  `CLAUDE.md` states the checkout is deliberately shared** — some toolchains drive a single
  fixed path and cannot follow a session into a worktree — in which case follow that file's
  procedural mitigations instead.
- When more than one feature is active at once (from this session or another), give each its own
  git worktree instead of stashing or switching branches in a single working tree, so uncommitted
  work on one feature never blocks or bleeds into another. Same exception as above: a project that
  documents its checkout as deliberately shared overrides this.
- Never push to a repo's default branch. Branch first, then open a pull request.
- Once a PR merges, delete the merged branch, switch back to `main`, and pull the latest `main`
  before starting the next task, so the next branch cuts from an up-to-date base.
- Every pull request body must follow the project's PR template.
- When the PR closes out a task that originated from a GitHub issue, include a closing keyword
  (`Closes #<number>`, `Fixes #<number>`, `Resolves #<number>`) in the PR body so merging to the
  default branch auto-closes the issue — never close the issue as a separate manual step.
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so it always describes the full current state of the branch — every
  change on it — not just what existed when it was opened. A stale PR description is a review
  hazard.
- Don't edit files under a path marked read-only/generated/vendored, if a project declares one
  (e.g. generated lockfiles, vendored dependency dirs, a build output directory).
