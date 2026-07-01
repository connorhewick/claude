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
- Decision (as answered): Generate CLAUDE.md from AGENTS.md via a sync script (not a symlink),
  chosen for distribution safety (Phase 0 = team distribution via plugin/marketplace, where
  symlinks may not survive packaging/zipping).
- Correction (2026-07-01, same session): Per Operating Rule 6, verified against current
  Claude Code docs (`memory.md`). Claude Code reads `CLAUDE.md` only, not `AGENTS.md`, and the
  documented mechanism for exactly this scenario is a `@AGENTS.md` import line at the top of
  CLAUDE.md — not a symlink, not a generate/sync script. This achieves the user's stated goal
  (avoid symlink fragility under packaging) with zero custom tooling and no drift risk, so it
  supersedes the sync-script approach without changing the underlying decision (AGENTS.md
  remains the single source of truth). `.claude/scripts/generate-claude-md.sh` was removed.
- Notes: `CLAUDE.md` = `@AGENTS.md` import + a short "## Claude Code" section for
  Claude-specific pointers, per the docs' own worked example.

## 2026-07-01 — Phase 1: Verification contract stages
- Question: Which verification stages should exist in the interface now (multi-select), though
  none are implemented?
- Decision: All six — format, lint, typecheck, test, build, security
- Default assumed (if deferred): n/a
- Notes: Declared as named slots only; zero implementations in this build. Avoids a future
  adapter author needing to extend the core interface for a standard stage.

## 2026-07-01 — Phase 2: Definition of "done"
- Question: Verification passes / Green CI / Human review required / Explicit acceptance
  criteria met? (multi-select)
- Decision: All four — verification passes, green CI, human review required, explicit
  acceptance criteria met
- Default assumed (if deferred): n/a
- Notes: All four must hold; none is sufficient alone.

## 2026-07-01 — Phase 2: Version-control conventions
- Question: Branch-naming scheme? Conventional Commits (yes/no)? PR body template needed
  (yes/no)?
- Decision: Conventional Commits + PR body template, both required
- Default assumed (if deferred): n/a
- Notes: No specific branch-naming scheme was requested beyond this; left unconstrained.

## 2026-07-01 — Phase 2: Documentation expectations
- Question: ADRs for significant decisions (yes/no)? Changelog maintained (yes/no)?
  (multi-select)
- Decision: ADRs for significant decisions — yes. Changelog — not selected (no).
- Default assumed (if deferred): n/a
- Notes: No changelog practice enforced in this build.

## 2026-07-01 — Phase 2: Absolute prohibitions
- Question: Never touch generated/vendored dirs / Never push to the default branch / Never
  rewrite git history / Never delete files without confirmation? (multi-select)
- Decision: Never push to the default branch; never touch generated/vendored dirs (concrete
  paths configured per-project, no hardcoded list in the agnostic core).
- Default assumed (if deferred): n/a
- Notes: "Never rewrite git history" and "never delete files without confirmation" were
  considered and explicitly not selected as hard guardrails in this build. They can be added
  later by extending `.claude/hooks/guard-bash.sh` / `.claude/hooks/guard-edits.sh` (Phase 4)
  without touching the core contract.
