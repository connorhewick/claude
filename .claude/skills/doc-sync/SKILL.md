---
name: doc-sync
description: >
  Detect and fix drift between the code and the files that must stay in sync
  with it (.claude/sync-paths). Runs the explorer, verifier, planner, doc-writer,
  and reviewer agents as one coordinated team over a diff range. Triggers for:
  "sync the docs", "are the docs stale", "keep the README in sync", "run doc-sync",
  "check for documentation drift", "did the docs keep up". Two modes: report
  (read-only — used by the pre-push gate and prepare-pr) and fix (applies doc
  edits — the default when invoked interactively). Do NOT auto-trigger during
  unrelated work; it is invoked deliberately (/doc-sync) or by the pre-push hook.
disable-model-invocation: true
allowed-tools: Task, Read, Edit, Write, Glob, Grep, Bash(git *), Bash(.claude/verify *)
---

Keep the files in `.claude/sync-paths` truthful against the code. Orchestrate the five role
subagents in sequence — do not do their work inline; delegate so each runs in its own context.

## Invocation

`/doc-sync [mode] [range]`

- **mode** — `fix` (default) applies doc edits; `report` is read-only (audits and records
  findings, edits nothing). The pre-push gate and `prepare-pr` pass `report`.
- **range** — a git range like `origin/main..HEAD`. If omitted, use the commits not yet on the
  upstream (`@{push}..HEAD`, falling back to `origin/main..HEAD`); if there is no such range,
  fall back to the working tree (`git status` + `git diff HEAD` + untracked files).

## Inputs

- `.claude/sync-paths` — the roster of files to keep in sync (the "what").
- `.claude/doc-sync.manifest` — per-file scope (the "how"): `tracks:<glob>` (file documents
  that code) and `mirrors:<path>` (file must stay consistent with a sibling). A roster path
  with no manifest line defaults to `tracks:**`.

## Procedure

Run the team in order. Scope every step to the diff range and the manifest — never re-audit
the whole repo when the manifest says a file only tracks a subtree.

1. **explorer** — For the range, find which changed code intersects each sync-path's
   `tracks:` globs, and which `mirrors:` pairs have diverged. Return candidate drift per file:
   the changed thing, and the doc section that references it. Read-only.
2. **verifier** — Confirm each candidate is real drift, not a false positive: does the file
   actually make a claim the code now contradicts? Also run `.claude/verify --json` so the
   docs don't describe a stage as passing when it is absent/failing. Read-only.
3. **planner** — Turn confirmed drift into an exact edit list: file, section, and the specific
   correction. No prose padding — only edits that fix a real inaccuracy. Read-only.
4. **doc-writer** — In **fix** mode, apply the edit list to the doc files (nothing else — no
   source/config/hooks). In **report** mode, do not edit; hand the edit list back. Keep the
   ToC and anchors correct if a section is added/removed (per `.claude/rules/docs.md`).
5. **reviewer** — Audit the result: in fix mode, review the doc diff for over-claiming or new
   inaccuracy; in report mode, sanity-check the edit list. Read-only.

## Output contract

End every run with a single machine-readable verdict line, then the findings:

```
DOC_SYNC_RESULT: PASS      # every file in .claude/sync-paths is accurate against the code
DOC_SYNC_RESULT: DRIFT     # at least one file has drifted
```

Follow it with human-readable findings — per file, the drift and the edit that fixes it (in fix
mode, which edits were applied). The pre-push gate greps this exact verdict line to decide
whether to block, so keep the prefix and casing verbatim.

- **report** mode is read-only: create and edit no files. The caller (the pre-push gate or the
  session) consumes your output directly; the gate captures it to `.claude/doc-sync.log`.
- **fix** mode applies the edit list to the doc files (nothing else — no source/config/hooks),
  then emits the verdict and a summary of applied edits.

Never commit and never push — staging the doc fixes into a commit is the human's call (or the
commit-chunking flow's), per the repo's "never auto-commit" convention.
