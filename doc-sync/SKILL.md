---
name: doc-sync
description: >
  Detect and fix drift between the code and the docs that describe it (README,
  docs/**, or an explicit file list), or deepen README.md in place with new
  onboarding-grade sections. Runs the explorer, planner, doc-writer, and
  reviewer agents in sequence over a diff range (or, in deepen mode, over the
  whole codebase). Triggers for: "sync the docs", "are the docs stale", "keep
  the README in sync", "run doc-sync", "check for documentation drift", "did
  the docs keep up", "deepen the README", "onboard someone to this repo via
  the README". Three modes: report (read-only — audits and records findings),
  fix (applies doc edits — the default when invoked interactively), and deepen
  (adds/refreshes Architecture Overview, Common Development Tasks, Gotchas,
  and Key Files sections in README.md). Do NOT auto-trigger during unrelated
  work; it is invoked deliberately (/doc-sync).
disable-model-invocation: true
allowed-tools: Task, Read, Edit, Write, Glob, Grep, Bash(git *)
argument-hint: > 
  [mode] [range] [paths...]
---

Keep a project's documentation truthful against its code. Orchestrate the four roles below in
sequence — do not do their work inline; delegate so each runs in its own context. These roles
are bundled with this skill, not separately installed agents: for each step, read the named
`doc-sync/<role>-agent.md` file's body (everything after its frontmatter) and pass it as the
prompt to the `Agent` tool, dispatched via `subagent_type: general-purpose` for `doc-writer` and
`reviewer`, or the built-in `Explore`/`Plan` types for `explorer`/`planner` (those already match
those two roles closely). Append the step's task-specific instructions — the diff range, the
paths in scope, and the prior step's output — after the bundled role-prompt.

## Invocation

`/doc-sync [mode] [range] [paths...]`

- **mode** — `fix` (default) applies doc edits; `report` is read-only (audits and records
  findings, edits nothing); `deepen` adds/refreshes onboarding-grade sections in `README.md`
  (see "Deepen mode" below) instead of chasing drift.
- **range** — a git range like `origin/main..HEAD`. If omitted, use the commits not yet on the
  upstream (`@{push}..HEAD`, falling back to `origin/main..HEAD`); if there is no such range,
  fall back to the working tree (`git status` + `git diff HEAD` + untracked files). Ignored in
  `deepen` mode, which surveys the whole current codebase rather than a diff (a `range` argument,
  if given anyway, is passed through unused and has no effect).
- **paths** — which docs to audit. If omitted: `README.md` plus everything under `docs/**`, if
  present. If the project has its own manifest of docs-to-code relationships (a "what should
  stay in sync" file, whatever it's called there), read and honor it instead of guessing. In
  `deepen` mode, `paths` instead scopes which parts of the *codebase* the explorer surveys (e.g.
  restrict a monorepo survey to `services/api/`); the doc target is always `README.md`, never a
  path argument.

## Procedure

Run the team in order. In `fix`/`report` mode, scope to the diff range and the given (or
defaulted) paths — never re-audit the whole repo when only a subtree is in scope. In `deepen`
mode, there is no diff range to scope to; the explorer surveys the codebase (or the given
`paths` subtree) directly.

1. **explorer** (`doc-sync/explorer-agent.md`, dispatched as `Explore`) — In `fix`/`report` mode,
   for the range, find which changed code is described or claimed-about by each doc path in
   scope; return candidate drift per file: the changed thing, and the doc section that
   references it. In `deepen` mode, survey the codebase (language/framework, directory
   structure, entry points, config files, git history) and read the current `README.md` to see
   what it already covers. Read-only in every mode.
2. **planner** (`doc-sync/planner-agent.md`, dispatched as `Plan`) — In `fix`/`report` mode, turn
   candidate drift into an exact edit list: file, section, and the specific correction — no
   prose padding, only edits that fix a real inaccuracy the explorer found. In `deepen` mode,
   turn the survey into drafted content for up to four new/refreshed `README.md` sections (see
   "Deepen mode" below), skipping any section the current README already covers adequately.
   Read-only in every mode.
3. **doc-writer** (`doc-sync/doc-writer-agent.md`, dispatched as `general-purpose`) — In **fix**
   mode, apply the edit list to the doc files (nothing else — no source/config). In **report**
   mode, do not edit; hand the edit list back. In **deepen** mode, apply the planner's drafted
   sections directly into the existing `README.md` (never a second file).
4. **reviewer** (`doc-sync/reviewer-agent.md`, dispatched as `general-purpose`) — Audit the
   result: in fix mode, review the doc diff for over-claiming or new inaccuracy; in report mode,
   sanity-check the edit list; in deepen mode, run the deepen-specific quality checklist (see
   "Deepen mode" below) before handoff. Read-only in every mode.

## Deepen mode

`/doc-sync deepen [paths...]` grows `README.md` in place with onboarding-grade sections a
newcomer needs but a drift-focused pass wouldn't produce — it never creates a second file
(no `docs/onboarding.md`, no API-reference/OpenAPI generation; both were considered and
explicitly dropped for this skill). The planner drafts up to four sections, each added only if
the current `README.md` doesn't already cover it adequately:

1. **Architecture Overview** — an ASCII diagram of the codebase's real structure, plus one
   representative real flow traced end-to-end through actual files (not described in the
   abstract) — e.g., for a component-library-shaped repo, how one real component's source file
   travels through the install script into the installed-to directory and back out via the
   uninstall script; for a service, one real request's path from entry point to response.
2. **Common Development Tasks** — the project's own most common change, verified against its
   actual current scripts/config. If the README already has an equivalent section (e.g. an
   "Adding a new component" walkthrough), the planner must explicitly decide — and state which —
   whether this subsumes/replaces it, extends it, or is redundant with it (and is therefore
   skipped); never draft a duplicate section addressing the same task.
3. **Gotchas and Non-Obvious Things** — genuine traps verified by reading the actual
   implementation (e.g. a backup-before-overwrite mechanic, an ordering dependency, a silent
   fallback) — never generic advice or a restatement of "read the docs."
4. **Key Files to Read First** — an ordered list of 5-8 files, one-sentence rationale each,
   ordered for progressive understanding (foundational/entry-point files before
   detail/leaf files).

## Output

End every run with a plain-language verdict. In `fix`/`report` mode: either "docs are accurate
against `<range>`" or a list of drifted files with what's wrong and (in fix mode) what was
changed. In `deepen` mode: which of the four sections were added/refreshed, which were skipped
as already adequately covered (and why), and how the "Common Development Tasks" section relates
to any pre-existing equivalent section. Never commit and never push — staging the doc fixes into
a commit is the human's call (or a commit-splitting skill's), not this skill's.
