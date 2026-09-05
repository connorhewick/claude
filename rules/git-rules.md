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
- Before the first edit in any new session, check `git status`/`git branch --show-current` —
  always; no exception below waives this check. If the working tree already has uncommitted
  changes or sits on a branch unrelated to the task at hand, treat that as another session's
  in-progress work, not something safe to build on top of, stash, or switch away from — start
  the new task in its own git worktree (`EnterWorktree`/`ExitWorktree`) instead of editing the
  shared checkout. Do this even if this is the session's very first action: a fresh session has
  no memory of what else may already be running against the same checkout, so opening a new
  terminal tab and starting a new task must never risk interfering with work already in progress
  there.
- When more than one feature is active at once (from this session or another), give each its own
  git worktree instead of stashing or switching branches in a single working tree, so uncommitted
  work on one feature never blocks or bleeds into another.
- **Shared-checkout exception.** It waives the worktree remedy in the two bullets above, and
  nothing else. Both conditions must hold: the task in front of you needs a toolchain pinned to
  one fixed checkout path (an IDE or build server that cannot follow a session into a worktree),
  and the project declares that checkout shared in its own
  `AGENTS.md`/`CLAUDE.md`/`CLAUDE.local.md`/`.claude/rules/*.md` — open that file and confirm the
  declaration; never infer it from a build path alone. A task that doesn't need the pinned
  toolchain still gets its own worktree, and the exception covers the primary checkout only:
  inside a worktree the project's declaration is a copied file, not a live condition. Everything
  those bullets ask for apart from the worktree still binds — run the status check first, and
  never stash, switch away from, discard, or build on top of another session's uncommitted work.
  Follow the project file's procedural mitigations for the rest; where it documents none for the
  situation in front of you, or where branching in the shared tree would carry another session's
  dirty files onto your branch, stop and ask rather than proceed.
- Never push to a repo's default branch. Branch first, then open a pull request.
- Once a PR merges, delete the merged branch, switch back to `main`, and pull the latest `main`
  before starting the next task, so the next branch cuts from an up-to-date base. In a shared
  checkout, do this only when the tree is clean and on your own branch — checking out `main`,
  deleting a branch, or pulling moves the tree beneath any session still working in it; when it
  isn't, leave the tree alone and say so.
- Every pull request body must follow the project's PR template.
- When the PR closes out a task that originated from a GitHub issue, include a closing keyword
  (`Closes #<number>`, `Fixes #<number>`, `Resolves #<number>`) in the PR body so merging to the
  default branch auto-closes the issue — never close the issue as a separate manual step.
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so it always describes the full current state of the branch — every
  change on it — not just what existed when it was opened. A stale PR description is a review
  hazard. Describe only the commits you meant to ship: if the range carries commits another
  session added, flag them to the user rather than writing them up as your own.
- Don't edit files under a path marked read-only/generated/vendored, if a project declares one
  (e.g. generated lockfiles, vendored dependency dirs, a build output directory).
