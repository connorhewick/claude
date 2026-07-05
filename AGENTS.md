<!--
  Portable, tool-agnostic source of truth for agent context. CLAUDE.md imports this file
  via `@AGENTS.md` — do not duplicate these rules in CLAUDE.md; add Claude-specific-only
  notes there instead. Keep this file language/stack-agnostic and under ~200 lines.
-->

# Engineering conventions

## Definition of done

A change is done only when **all** of the following hold:
- The verification contract passes for every stage relevant to the change
  (`.claude/verify` — see `.claude/CONTRACT.md`). Until a stack adapter registers, this
  fails closed by design; that is expected, not a bug to work around.
- CI is green.
- A human has reviewed and approved the change.
- The task's stated acceptance criteria are met.

None of these alone is sufficient. Do not declare a task complete on partial satisfaction of
this list.

## Version control

- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, …) for
  every commit message.
- When committing work that spans more than one distinct concern, split it into one logical,
  atomic commit per concern (the `split-commits` skill / `/split-commits`) rather than a single
  mixed commit. Always present the commit plan and get approval before committing — never
  auto-commit.
- Every pull request body must follow the project's PR template.
- Keep an open PR's title and description accurate as its branch evolves. After pushing new
  commits to a branch that already has an open PR, update the PR (`gh pr edit <number>
  --title ... --body ...`) so the title and body always describe the full current state of the
  branch — every change on it — not just what existed when the PR was opened. A stale PR
  description is a review hazard.
- Never push directly to the default branch. All changes go through a branch and a pull
  request.

## Documentation

- Write an ADR for any significant or hard-to-reverse architectural decision. Use the
  `adr-writer` skill if available; otherwise use a lightweight template capturing context,
  decision, and consequences.
- Prefer short descriptive names over bare identifiers when referencing tickets (Jira, etc.)
  or documents (PRDs, ADRs). Use `PROJ-142-oauth-token-refresh` rather than `PROJ-142`, and
  `ADR4-postgres-over-dynamo` rather than `ADR4`. The description makes the reference
  self-explanatory when resuming a session's task later, without needing to re-open the
  ticket or document to recall what it covers.

## Absolute prohibitions

- Never push to the default branch.
- Never edit files under a path marked read-only/generated/vendored in `.claude/rules/`.
  These paths are configured per-project (this harness ships no hardcoded list, since it has
  no stack yet).

## Arbiter of "done"

When in doubt about whether something is finished, defer to the verification contract
(`.claude/CONTRACT.md`) over intuition — it is the single source of truth for correctness.
