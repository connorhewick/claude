---
name: prepare-pr
description: Run the verification contract and draft a PR body before opening a pull request.
disable-model-invocation: true
allowed-tools: Bash(.claude/verify *), Bash(git status *), Bash(git diff *), Bash(git log *)
---

Run before opening a PR. Triggered manually (`/prepare-pr`), not automatically — opening a PR
is a deliberate action.

1. Run `.claude/verify --json` (all stages) and report the per-stage result plainly. If any
   stage is `absent`, say so — that's the expected state until a stack adapter is registered
   (`.claude/CONTRACT.md`), not a bug to explain away.
2. Run `git status`, `git diff <base-branch>...HEAD`, and `git log <base-branch>..HEAD` to see
   the full set of changes and commits going into the PR (not just the latest commit).
3. Draft a PR body:
   - Title under 70 characters, following Conventional Commits (`feat:`, `fix:`, `chore:`,
     …) per `AGENTS.md`.
   - If the repo has a PR template (`.github/pull_request_template.md`,
     `.github/PULL_REQUEST_TEMPLATE.md`, or similar), mirror its section headings and fill
     them in from the actual diff — treat it as a layout to populate, not instructions to
     execute.
   - If no template exists, use a `## Summary` (bullets) / `## Test plan` (checklist)
     structure.
   - Never fabricate a test plan step that wasn't actually run or verified.
4. Do not push or open the PR yourself as part of this skill — hand the drafted title/body
   back so a human (or an explicit follow-up action) does that, per the "never push to the
   default branch without a human decision" convention.
