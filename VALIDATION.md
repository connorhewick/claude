# Validation

End-to-end checklist and results for the language-agnostic harness build (Phases 0–8). All
items below were actually executed, not just inspected.

## Context layer (Phase 2)

| Check | Result |
|---|---|
| `AGENTS.md` under 200 lines | Pass — 46 lines |
| `CLAUDE.md` correctly imports `AGENTS.md` via `@AGENTS.md` | Pass — verified against current Claude Code docs (`memory.md`); corrected from an earlier generate-script approach after checking |
| No rule names a language/stack tool | Pass — grepped `AGENTS.md` and `.claude/rules/*.md` for common language/tool names; only false positive was "go through" |

## Guardrail layer (Phase 4)

All three `PreToolUse` hooks red-teamed in both `advisory` and `blocking` modes:

| Scenario | Advisory mode | Blocking mode |
|---|---|---|
| Edit under a protected path (`dist/**`) | Reported, exit 1 (non-blocking) | Denied, exit 2 |
| Content with a hardcoded secret pattern | Reported, exit 1 | Denied, exit 2 |
| Normal file edit | Passes silently, exit 0 | Passes silently, exit 0 |
| `rm -rf` | Reported, exit 1 | Denied, exit 2 |
| `curl \| bash` | Reported, exit 1 | Denied, exit 2 |
| `git push --force` to the default branch | — | Denied, exit 2 |
| `git push --force` to a feature branch | — | Allowed, exit 0 |
| Branch name matching neither naming scheme | Reported, exit 1 | Denied, exit 2 |
| Branch name matching either scheme | Passes, exit 0 | Passes, exit 0 |

## Verification contract (Phases 1 & 5)

| Check | Result |
|---|---|
| `.claude/verify` (all stages), `verify.d/` empty | Fails closed, exit 1, every stage reported `absent` |
| `.claude/verify --json` | Valid JSON, correct per-stage `absent` status |
| `.claude/verify <unknown-stage>` | Rejected with a clear error, exit 1 |
| Adapter registration (`verify.d/<stage>`, executable) | A mock `test` adapter was registered and correctly produced `pass`/exit 0 |
| Stop-gate (`verify-gate.sh`), `advise` mode | Surfaces the fail-closed result via `systemMessage`/`additionalContext`; does not block stopping |
| Stop-gate, `block` mode | Emits `hookSpecificOutput.decision: "block"` with the failure detail |

## Orchestration layer (Phase 6)

All five subagents dry-run invoked live in this session (not just statically inspected):

| Role | Result |
|---|---|
| `planner` | Confirmed no Write/Edit tools; correctly identified its own role |
| `explorer` | Found `.claude/CONTRACT.md`'s path; confirmed read-only, no Write/Edit |
| `reviewer` | Read `AGENTS.md`, correctly identified that the verification-passes criterion of "done" fails by design pre-adapter; confirmed no Write/Edit |
| `verifier` | Ran `.claude/verify --json` itself and correctly reported all six stages `absent` as the intentional state |
| `doc-writer` | Confirmed full Write/Edit access, correctly scoped by instruction to docs only |

No subagent prompt names a language or stack tool (grepped).

## Skills layer (Phase 7)

| Check | Result |
|---|---|
| Skills load on demand without a session restart | Confirmed — each of `spec-first-planning`, `write-adr`, `prepare-pr` appeared in the available-skills list immediately after being written, unlike subagents (which required a context refresh) |
| No skill hardcodes a stack tool | Pass (grepped) |

## Packaging & distribution (Phase 8)

| Check | Result |
|---|---|
| `scripts/build-plugin.sh` produces `plugin/` | Ran once; `plugin/.claude-plugin/plugin.json` and `plugin/hooks/hooks.json` both validated as well-formed JSON (`jq .`) |
| `.claude-plugin/marketplace.json` well-formed | Validated with `jq .` |
| `plugin/**` protected by the generated-paths guardrail | Confirmed — a simulated edit under `plugin/` was denied |
| `scripts/bootstrap.sh` end-to-end, on a throwaway directory | Vendored `.claude/`, `AGENTS.md`, `CLAUDE.md`, `.mcp.json` correctly; excluded `.claude/settings.local.json` and `.claude/scripts/`; refused to run against a directory that already had `.claude/` |

## Full end-to-end dry run (Phase 9)

Run on an independent, freshly-bootstrapped throwaway project (no relation to this repo's own
`.claude/` in-session config):

1. **Create a file** — a normal edit passed silently (exit 0).
2. **Attempt a blocked action** — an edit under `dist/**` was denied in blocking mode (exit 2),
   with a clear reason.
3. **Attempt a blocked command** — `rm -rf ...` was denied in blocking mode (exit 2).
4. **Run `verify`** — failed closed with `verify.d/` empty; all six stages reported `absent`;
   overall exit 1.
5. **Stop-gate, advise mode** — surfaced the failure as context without blocking completion.

All five behaved exactly as designed.

## Global Acceptance Criteria (from the implementation plan)

| Criterion | Status |
|---|---|
| Every phase's interview answers recorded in `DECISIONS.md` | Done |
| Always-on context minimal, no stack-specific rule | Done |
| Guardrails deterministic, fail closed; red-teamed | Done |
| `verify` runs, exposes the full contract, fails closed with `verify.d/` empty | Done |
| Subagents respect tool-scopes; no role/skill names a language/stack tool | Done |
| Harness installs cleanly via the chosen distribution mechanism | Done (plugin build + bootstrap script both tested) |
| Handoff seam documented so a future task can add a language capability without editing the core | See README "Handoff" section |
