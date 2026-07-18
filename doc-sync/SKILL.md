---
name: doc-sync
description: >
  Detect and fix drift between the code and the docs that describe it (README,
  docs/**, or an explicit file list). Runs the explorer, planner, doc-writer,
  and reviewer agents in sequence over a diff range. Triggers for: "sync the
  docs", "are the docs stale", "keep the README in sync", "run doc-sync",
  "check for documentation drift", "did the docs keep up". Two modes: report
  (read-only — audits and records findings) and fix (applies doc edits — the
  default when invoked interactively). Do NOT auto-trigger during unrelated
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
prompt to the `Task` tool, dispatched via `subagent_type: general-purpose` for `doc-writer` and
`reviewer`, or the built-in `Explore`/`Plan` types for `explorer`/`planner` (those already match
those two roles closely). Append the step's task-specific instructions — the diff range, the
paths in scope, and the prior step's output — after the bundled role-prompt.

## Invocation

`/doc-sync [mode] [range] [paths...]`

- **mode** — `fix` (default) applies doc edits; `report` is read-only (audits and records
  findings, edits nothing).
- **range** — a git range like `origin/main..HEAD`. If omitted, use the commits not yet on the
  upstream (`@{push}..HEAD`, falling back to `origin/main..HEAD`); if there is no such range,
  fall back to the working tree (`git status` + `git diff HEAD` + untracked files).
- **paths** — which docs to audit. If omitted: `README.md` plus everything under `docs/**`, if
  present. If the project has its own manifest of docs-to-code relationships (a "what should
  stay in sync" file, whatever it's called there), read and honor it instead of guessing.

## Procedure

Run the team in order, scoped to the diff range and the given (or defaulted) paths — never
re-audit the whole repo when only a subtree is in scope.

1. **explorer** (`doc-sync/explorer-agent.md`, dispatched as `Explore`) — For the range, find
   which changed code is described or claimed-about by each doc path in scope. Return candidate
   drift per file: the changed thing, and the doc section that references it. Read-only.
2. **planner** (`doc-sync/planner-agent.md`, dispatched as `Plan`) — Turn candidate drift into
   an exact edit list: file, section, and the specific correction. No prose padding — only edits
   that fix a real inaccuracy the explorer found. Read-only.
3. **doc-writer** (`doc-sync/doc-writer-agent.md`, dispatched as `general-purpose`) — In **fix**
   mode, apply the edit list to the doc files (nothing else — no source/config). In **report**
   mode, do not edit; hand the edit list back.
4. **reviewer** (`doc-sync/reviewer-agent.md`, dispatched as `general-purpose`) — Audit the
   result: in fix mode, review the doc diff for over-claiming or new inaccuracy; in report mode,
   sanity-check the edit list. Read-only.

## Output

End every run with a plain-language verdict — either "docs are accurate against `<range>`" or a
list of drifted files with what's wrong and (in fix mode) what was changed. Never commit and
never push — staging the doc fixes into a commit is the human's call (or a commit-splitting
skill's), not this skill's.
