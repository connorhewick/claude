# claude-config

Portable Claude Code defaults: one always-on `CLAUDE.md`, a set of rules, and skills for the
procedures. Stack-agnostic — nothing names a language or framework.

## Install

```sh
./install.sh --dry-run   # print the plan, write nothing
./install.sh             # check, back up, install, prune, report
```

`install.sh` copies `claude-rules/global-rules.md` to `~/.claude/CLAUDE.md`, the other rules to
`~/.claude/rules/` and the skills to `~/.claude/skills/`, and does what a plain copy does not:

- **Runs `check.sh` first** and refuses to install on a failure: a dangling file, section or
  skill reference, or frontmatter that would silently make a rule always-on.
- **Warns when the checkout is not on the default branch**, because that installs unmerged
  config into every session on the machine.
- **Backs up** whatever is already at those paths, to `~/.claude/.backups/<timestamp>/`, before
  writing anything.
- **Prunes** what a previous install of this bundle placed and this one no longer has, using the
  manifest it writes. Without it, a rule deleted here keeps loading there forever. Each skill
  directory is replaced whole, so a file deleted inside a skill goes too.
- **Reports rule files and skills it does not own**, with whether each rule is always-on. Two
  files disagreeing about the same thing is the one failure nothing detects at runtime: the model
  picks one. If you already have a personal bundle installed, read that list before the first
  session and delete the loser.

It also prints the measured always-on budget and the slash commands the bundle names. Then, in a
**new** session: `/context` to confirm what loaded, `/doctor` to check the setup. A running
session does not pick up changed configuration.

## Layout

| Path | Tier | Loads |
|---|---|---|
| `claude-rules/global-rules.md` | always-on | every session, installed as `~/.claude/CLAUDE.md` |
| `claude-rules/security.md` | always-on | every session |
| `claude-rules/session-hygiene.md` | always-on | every session |
| `claude-rules/code.md` | path-scoped | a code file is read |
| `claude-rules/testing.md` | path-scoped | a test file is read |
| `claude-rules/contracts.md` | path-scoped | a contract, migration or schema file is read |
| `claude-rules/rules-authoring.md` | path-scoped | a rule file, a `CLAUDE.md` or an `AGENTS.md` is read |
| `claude-skills/ship` | on demand | "ship this", "open a PR" |
| `claude-skills/walkthrough` | on demand | before a PR; "walk me through it" |
| `claude-skills/review-pr` | on demand | "review PR #n" |
| `claude-skills/issues` | on demand | "work on #n", "file an issue" |
| `CLAUDE.md` | not installed | sessions opened in this repo — how to work on the bundle |

**The always-on tier is the budget worth watching**, and `install.sh` measures it on every run
rather than this file carrying a number that drifts. Before adding anything to it, ask whether
the fact shapes *every* session, or only sessions that touch certain files (a rule) or run a
certain procedure (a skill).

## Ownership

Each fact lives in exactly one file; every other file points at it. When two files could both
say something, this table decides which does.

| Fact | Owner |
|---|---|
| Generated-document contents (table of contents) | `claude-rules/global-rules.md` §Generated documents |
| Flags, rollback, watching a change land after merge | `claude-skills/ship` §Say how it is turned off |
| Code design, errors, concurrency, logging | `claude-rules/code.md` |
| When a comment earns its place; debugging | `claude-rules/code.md` |
| What earns a test, test shape, determinism, flakes | `claude-rules/testing.md` |
| Published-contract, breaking-change and migration rules | `claude-rules/contracts.md` |
| `/security-review` trigger list; secrets; production data | `claude-rules/security.md` |
| Repository-state checks; unrecognised commits; when to start fresh | `claude-rules/session-hygiene.md` |
| Rule-file form, scoping, reversal, file-versus-section | `claude-rules/rules-authoring.md` |
| Pre-PR checks, the diff read-through, the PR body template, draft state | `claude-skills/ship` |
| Pre-PR walkthrough and interview | `claude-skills/walkthrough` |
| Picking up, filing and cross-referencing issues; labels; assignment | `claude-skills/issues` |
| Severity bar for someone else's PR | `claude-skills/review-pr` |
| Model tier, agent shape, fan-out cost, verifying what comes back, integration branches | `claude-rules/session-hygiene.md` §Subagents and fan-out |
| What invoking a skill authorises (push, never merge) | that skill's preamble |
| Editing this bundle: checks, reference form, skills' `allowed-tools`, naming commands | `CLAUDE.md` |
