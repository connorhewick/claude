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

## 2026-07-01 — Phase 3: Concrete capability providers
- Question: For each Phase 0 capability domain (version control, issue tracker, documentation
  search), which concrete service?
- Decision: GitHub (version control), Jira (issue tracker), Confluence (documentation search).
- Default assumed (if deferred): n/a
- Notes: Domains confirmed; see next entry for why wiring is deferred.

## 2026-07-01 — Phase 3: MCP server implementation
- Question: Credential handling and read/write scope for the GitHub, Jira, and Confluence MCP
  servers?
- Decision: Deferred. These three servers will be added later as nested repos rather than
  configured inline in this build's `.mcp.json`.
- Default assumed (if deferred): `.mcp.json` stays the Phase 1 placeholder (empty
  `mcpServers`); no credential/scope decision is locked yet — must be made when each nested
  repo is actually wired in.
- Notes: User confirmed no skill/agent/rule is needed merely for these servers to exist —
  Claude Code discovers and calls MCP tools automatically. Dedicated rules/skills become
  relevant only for workflow policy about *how* to use them (e.g. link Jira tickets in PRs),
  which is deferred to whenever that policy is actually wanted, not built speculatively now.

## 2026-07-01 — Phase 4: Protected paths
- Question: Which paths are hard-blocked from edits (generated dirs, vendored deps,
  lockfiles, `.claude/` itself)?
- Decision: Generated/vendored dirs only, reusing the exact glob list already declared in
  `.claude/rules/generated-paths.md` (single source of truth — the hook parses that file's
  frontmatter rather than duplicating the patterns).
- Default assumed (if deferred): n/a
- Notes: Lockfiles and `.claude/` itself were considered and not selected in this build.

## 2026-07-01 — Phase 4: Hard-blocked shell patterns
- Question: Confirm defaults (recursive force-delete, force-push to the default branch,
  piping remote scripts into a shell) and add any others?
- Decision: All three defaults, no additions.
- Default assumed (if deferred): n/a

## 2026-07-01 — Phase 4: Branch-name enforcement
- Question: Enforce a branch-naming scheme at commit/PR time (yes/no)? If yes, what scheme?
- Decision: Yes. Scheme: `<TICKET-ID>/<short-description>` by default (e.g.
  `PROJ-123/add-login`); falls back to `<type>/<short-description>` (type in
  feat|fix|chore|docs|refactor|test) when no ticket exists.
- Default assumed (if deferred): n/a
- Notes: Enforced by `.claude/hooks/guard-branch-name.sh` on `git checkout -b` / `git switch
  -c` / `git branch <name>`.

## 2026-07-01 — Phase 4: Rollout mode
- Question: Start blocking immediately, or log-only first (per Phase 0 risk posture)?
- Decision: Advisory (log-only) first, confirming the Phase 0 answer. Single switch:
  `HARNESS_GUARDRAIL_MODE` in `.claude/settings.json`'s `env` block (`advisory` | `blocking`).
- Default assumed (if deferred): n/a
- Notes: All three hooks were red-teamed in both modes — see README "Guardrails" section.
  Verified hooks.md schema (event names, matcher syntax, exit-code semantics, JSON stdin/stdout
  shape) against current Claude Code docs before implementing, per Operating Rule 6.

## 2026-07-01 — Phase 5: Fail-closed default
- Question: When no verification adapter is registered, should verify block completion or
  warn-only?
- Decision: Block (exits non-zero) — confirms the Phase 1 CONTRACT.md spec already built; no
  rework needed.
- Default assumed (if deferred): n/a

## 2026-07-01 — Phase 5: Stop-gate strength
- Question: Should the Stop hook hard-block the agent from finishing until verify passes, or
  just advise?
- Decision: Advise only, for this build. `HARNESS_VERIFY_STOP_MODE=advise` in
  `.claude/settings.json`. A non-passing verify result (including every stage `absent`, as
  today) is surfaced as feedback but does not prevent the session from finishing.
- Default assumed (if deferred): n/a
- Notes: This is a separate switch from the Phase 4 `HARNESS_GUARDRAIL_MODE`. Flip to `block`
  once a real verify.d/ adapter exists, if hard-gating "done" on verification is wanted.
  Verified Stop-hook JSON output schema (`hookSpecificOutput.decision: "block"`,
  `additionalContext`) against current docs before implementing, per Operating Rule 6.

## 2026-07-01 — Phase 6: Roles to include
- Question: Which role subagents to include (multi-select) — Planner / Explorer / Reviewer /
  Verifier / Doc-writer / Other?
- Decision: All five — Planner, Explorer, Reviewer, Verifier, Doc-writer.
- Default assumed (if deferred): n/a

## 2026-07-01 — Phase 6: Per-role model defaults
- Question: Given Phase 0 chose Sonnet-default overall, should any role deviate?
- Decision: Left as an open item, dependent on available token-usage limits at run time. The
  harness must be usable across Haiku, Sonnet, and Opus rather than pinning a model per role.
- Default assumed (if deferred): Every role's frontmatter sets `model: inherit`, so each
  subagent runs on whatever model the invoking session/user has selected, rather than a
  hardcoded default. This is a real default choice (not merely deferred), made because it's
  the only option compatible with "must work across all three models."
- Notes: Per current subagent docs, `model: inherit` resolves the same as omitting the field.

## 2026-07-01 — Phase 6: Per-role permissions and isolation
- Question: Read-only vs. read-write per role; worktree isolation where relevant?
- Decision: Planner/Explorer/Reviewer — `disallowedTools: Write, Edit, NotebookEdit` (no file
  writes). Verifier — `tools: Read, Glob, Grep, Bash` plus the same disallowedTools (can run
  `.claude/verify` via Bash, cannot edit). Doc-writer — full tool access, scoped to
  docs/README/ADRs by instruction only (not by frontmatter, since Claude Code's tool
  allowlist is by tool name, not by file path). No worktree isolation for any role in this
  build.
- Default assumed (if deferred): n/a
- Notes: A live dry-run of each role wasn't possible in the same session that created the
  agent files (new `.claude/agents/*.md` definitions load at session start, not mid-session).
  Verified statically instead: well-formed frontmatter, required `name`/`description` present,
  no stack/language reference in any prompt body. **Action for the user:** start a fresh
  session and dry-run invoke each role via the `Agent` tool to confirm live tool-scope before
  relying on it in production use.

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
