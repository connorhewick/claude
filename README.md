# Claude Code Harness

A reusable Claude Code harness for expert-level software engineering: context, capability,
guardrails, verification, and orchestration, packaged for reuse across projects.

The harness core is **language- and stack-agnostic**. See `SCOPE.md` for the locked decisions
and `DECISIONS.md` for the full interview log.

## Layout

```
AGENTS.md            portable source-of-truth context
CLAUDE.md             imports AGENTS.md via `@AGENTS.md` — do not duplicate rules here
DECISIONS.md          append-only interview/decision log
SCOPE.md              locked Phase 0 decisions + the language-agnostic invariant
.mcp.json             cross-stack MCP servers only
.claude/
  settings.json        hooks + settings
  rules/*.md           path-scoped, language-agnostic rules
  hooks/*              deterministic guardrail scripts
  agents/*.md          language-agnostic role subagents
  skills/<name>/       reusable, language-agnostic procedures
  verify                verification contract entrypoint (fail-closed)
  verify.d/             adapter drop-in dir — EMPTY in this build
  CONTRACT.md            full spec of the verify interface
```

## Verification contract

`.claude/verify [stage] [--json]` is the single arbiter of "done." It fails closed: any
requested stage with no adapter in `.claude/verify.d/` is reported `absent` and the run exits
non-zero. See `.claude/CONTRACT.md` for the full interface and how a future stack adapter
registers.

## Capabilities

Three cross-stack capability domains are planned: version control (GitHub), issue tracking
(Jira), and documentation search (Confluence). None is wired into `.mcp.json` in this build —
they will be added later as nested repos rather than inline server definitions. When one is
added, its credential handling (env var reference, never an inline literal) and scope
(read-only vs. read-write) must be decided and recorded in `DECISIONS.md` at that time.

No skill, agent, or rule is required just for an MCP server to be usable — Claude Code
discovers and calls MCP tools on its own. Add a rule/skill/agent later only to encode actual
workflow policy about how a tool should be used.

## Guardrails

Three deterministic, fail-closed `PreToolUse` hooks, wired in `.claude/settings.json`:

| Hook | Matcher | Denies |
|---|---|---|
| `guard-edits.sh` | `Edit\|Write` | Edits to generated/vendored paths (globs sourced from `.claude/rules/generated-paths.md` — single source of truth); content that looks like a hardcoded secret (private key block, AWS access key, generic `secret`/`token`/`password`/`api_key` assignment). |
| `guard-bash.sh` | `Bash` | Recursive force-delete (`rm -rf` or equivalent); `git push --force`/`-f` targeting the default branch; piping a remote download into a shell (`curl \| sh`, etc.). |
| `guard-branch-name.sh` | `Bash` (branch-creation commands) | Branch names that don't match `<TICKET-ID>/<short-description>` (e.g. `PROJ-123/add-login`), falling back to `<type>/<short-description>` with `type` in `feat\|fix\|chore\|docs\|refactor\|test` when there's no ticket. |

**Rollout mode** is controlled by a single switch: `HARNESS_GUARDRAIL_MODE` in
`.claude/settings.json`'s `env` block.
- `advisory` (current default) — violations are reported (hook exits non-blocking) but the
  action proceeds.
- `blocking` — violations deny the action (hook exits 2).

Flip the value once the advisory period has validated the gates in practice; no other file
needs to change.

## Verification Stop-gate

`.claude/hooks/verify-gate.sh` runs `.claude/verify --json` on every `Stop` event. Its mode is
controlled by `HARNESS_VERIFY_STOP_MODE` in `.claude/settings.json` (`advise` default |
`block`), separate from the Phase 4 guardrail rollout switch.

With `verify.d/` intentionally empty in this build, every `verify` run fails closed — that's
expected, not a bug. In `advise` mode (current default) that failure is surfaced as context but
doesn't prevent the session from finishing; in `block` mode it would permanently block every
session from finishing until a real stack adapter is registered. Flip to `block` once the first
adapter lands, if you want "done" to be hard-gated by verification.

## Orchestration

Five role subagents in `.claude/agents/`, each narrow and behavior-defined (not tied to a
language or stack):

| Role | Use when | Tool scope |
|---|---|---|
| `planner` | Starting a non-trivial task that needs a plan first | No Write/Edit — returns a plan only |
| `explorer` | Open-ended codebase investigation | No Write/Edit — read-only, returns findings only |
| `reviewer` | Second opinion on a diff before declaring it done | No Write/Edit — read-only, reports findings |
| `verifier` | Checking whether a change passes verification | Read/Glob/Grep/Bash (to run `.claude/verify`), no Write/Edit |
| `doc-writer` | Recording a decision or fixing drifted docs | Full tool access, scoped by instruction to docs/README/ADRs only |

All five default to `model: inherit` (the invoking session's model) rather than a pinned
model — deliberately left open per Phase 0/6, since the harness should work across
Haiku/Sonnet/Opus depending on token budget, not assume one.

**Verifying tool-scope after adding/changing an agent file:** new or edited files under
`.claude/agents/` are picked up at the start of a session, not mid-session. After changing
one, start a fresh session and dry-run invoke it (e.g. via the `Agent` tool with
`subagent_type` set to the role name) to confirm its actual tool access matches the
frontmatter before relying on it.

## Status

This harness is under active build, phase by phase, per the interview-gated implementation
plan. See `DECISIONS.md` for progress.
