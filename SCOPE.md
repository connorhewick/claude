# Scope

This repo is a reusable Claude Code harness for expert-level software engineering, built as
five layered ports: context, capability, guardrails, verification, orchestration.

## Language-agnostic invariant

The harness core is agnostic of programming language and tech stack. Nothing in the core
assumes a language, framework, package manager, test runner, or linter. Stack-specific
capability is added later, as a separate task, by plugging into the extension seam defined in
Phase 5/the README "Handoff" section — never by editing the core.

## Locked decisions (Phase 0)

| Question | Decision |
|---|---|
| Deployment context | Team distribution |
| Harness home | Dedicated repo (this repo), applied across many projects |
| Target surfaces | CLI |
| Guardrail risk posture | Advisory (log-only) first, then tighten to blocking |
| Capability domains (now) | Version control, Issue tracker, Documentation search |
| Model posture | Sonnet-default |

Full rationale and any deferred defaults are in `DECISIONS.md`.

## What "done" means for this build

Per the plan's Global Acceptance Criteria: every phase's interview is recorded, context stays
minimal and stack-free, guardrails are deterministic and (per the chosen posture) start
advisory with a documented flip to blocking, the `verify` contract fails closed with
`verify.d/` empty, subagents respect tool-scopes, the harness installs via the chosen
distribution mechanism (plugin + marketplace, given team distribution), and the handoff seam
is documented unambiguously.
