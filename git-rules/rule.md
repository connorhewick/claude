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
  cleanly branching off `main` for its own task in the meantime. When more than one feature is
  active at once, give each its own git worktree (`EnterWorktree`/`ExitWorktree`) instead of
  stashing or switching branches in a single working tree, so uncommitted work on one feature
  never blocks or bleeds into another.
- Never push to a repo's default branch. Branch first, then open a pull request.
- Every pull request body must follow the project's PR template.
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so it always describes the full current state of the branch — every
  change on it — not just what existed when it was opened. A stale PR description is a review
  hazard.
- Don't edit files under a path marked read-only/generated/vendored, if a project declares one
  (e.g. generated lockfiles, vendored dependency dirs, a build output directory).
