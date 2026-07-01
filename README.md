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

## Status

This harness is under active build, phase by phase, per the interview-gated implementation
plan. See `DECISIONS.md` for progress.
