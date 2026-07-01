# Decisions Log

Append-only. Each entry: date, phase, the question, the chosen answer, and (if applicable)
the default assumed because the user deferred.

---

## 2026-07-01 — Phase 0: Deployment context
- Question: Solo use / Team distribution / Open-source?
- Decision: Team distribution
- Default assumed (if deferred): n/a
- Notes: Drives building a plugin + marketplace in Phase 8.

## 2026-07-01 — Phase 0: Harness home
- Question: Dedicated repo applied across many projects / Embedded in one project repo / Both?
- Decision: Dedicated repo
- Default assumed (if deferred): n/a
- Notes: This repo (connorhewick/claude) is the dedicated harness repo, applied to other
  project repos via install/bootstrap (mechanism TBD in Phase 8).

## 2026-07-01 — Phase 0: Target Claude Code surfaces
- Question: CLI / IDE extension / GitHub Action / Agent SDK? (multi-select)
- Decision: CLI only
- Default assumed (if deferred): n/a
- Notes: Other surfaces may be added later; nothing in this build should assume CLI-only
  behavior that would break IDE/Action/SDK use, but no extra work is done for them now.

## 2026-07-01 — Phase 0: Guardrail risk posture
- Question: Strict fail-closed from day one / Advisory (log-only) first, then tighten?
- Decision: Advisory first, then tighten
- Default assumed (if deferred): n/a
- Notes: Phase 4 guardrails ship as log-only with a single documented switch to flip to
  blocking once trusted. Verification Stop-gate strength (Phase 5) is a separate decision.

## 2026-07-01 — Phase 0: Capability domains needed now
- Question: Version control / Issue tracker / Documentation search / Read-only database /
  Internal APIs / None yet? (multi-select)
- Decision: Version control (GitHub/GitLab/…), Issue tracker, Documentation search
- Default assumed (if deferred): n/a
- Notes: Concrete providers (e.g. GitHub vs GitLab), credential handling, and scope
  (read-only vs read-write) are decided per-server in the Phase 3 interview. Read-only
  database and internal APIs are deferred — not needed now.

## 2026-07-01 — Phase 0: Model posture
- Question: Opus-default / Sonnet-default / Per-role mix?
- Decision: Sonnet-default
- Default assumed (if deferred): n/a
- Notes: Roles default to Sonnet unless a specific role's Phase 6 interview calls for an
  override.

## 2026-07-01 — Phase 1: Context source-of-truth
- Question: AGENTS.md source with CLAUDE.md symlink / maintain CLAUDE.md directly / generate
  CLAUDE.md from AGENTS.md?
- Decision: Generate CLAUDE.md from AGENTS.md via a sync script (not a symlink)
- Default assumed (if deferred): n/a
- Notes: Chosen for distribution safety (Phase 0 = team distribution via plugin/marketplace,
  where symlinks may not survive packaging/zipping). AGENTS.md is the single source of truth;
  `.claude/scripts/generate-claude-md.sh` regenerates CLAUDE.md as a real file. This must be
  re-run whenever AGENTS.md changes — documented in README, and worth revisiting for a
  pre-commit/CI check in a later phase.

## 2026-07-01 — Phase 1: Verification contract stages
- Question: Which verification stages should exist in the interface now (multi-select), though
  none are implemented?
- Decision: All six — format, lint, typecheck, test, build, security
- Default assumed (if deferred): n/a
- Notes: Declared as named slots only; zero implementations in this build. Avoids a future
  adapter author needing to extend the core interface for a standard stage.
