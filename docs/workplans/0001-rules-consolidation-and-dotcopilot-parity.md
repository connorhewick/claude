# Workplan 0001: rules consolidation, component-review technical-currency check, dotcopilot-parity enhancements

Date: 2026-07-23
Source issues: #43, #24, #22

## Execution order

Four fully independent items — no cross-item file conflicts except the noted #24/#43 pair, no cross-item dependencies. All four can run in parallel, each in its own worktree.

1. #24 — add a technical-currency check to `component-review` (sequence before #43 — same-file edit, not a real functional dependency)
2. #43 — consolidate git-rules/documentation-rules/swiftui-rules into one top-level `rules/` directory (after #24, same-file reason above)
3. #22 (doc-sync) — deepen README generation mode (fully independent; worktree: `../claude-issue-22-doc-sync/` on `feat/doc-sync-readme-deepening`)
4. #22 (prepare-pr) — change-walkthrough section only (fully independent; worktree: `../claude-issue-22-prepare-pr/` on `feat/prepare-pr-changelog-walkthrough`)
5. #22 (write-adr) — trade-off-analysis routing, bundled diagram, quality checklist (fully independent; worktree: `../claude-issue-22-write-adr/` on `feat/write-adr-tradeoff-and-checklist`)

**Deferred, not in this workplan's execution scope:** #22's `tdd-writer` new-skill sub-item — see "Decisions made during planning." Recommend filing it as its own separate GitHub issue before picking it up; not done here since opening an issue is a separate deliberate action.

Two tracks, each internally sequential:
- **Track A** (no worktree needed — small, sequential, shared-file edits): #24 → #43
- **Track B, C, D**: doc-sync, prepare-pr, write-adr — three independent worktrees, no ordering between them

## Per-issue detail

### #24 — Systematic technical-currency review of ios-engineering's reference files and SKILL.md routing

**Resolved scope:** Items 1 (per-reference audit) and 3 (routing-table pass) are **already done and merged into `main`** — verified directly: commits `19466a6`, `9efed4e`, `79a65e8` (SwiftData-first defaults, router wiring, CloudKit-sharing trigger) are all ancestors of `main`, and the specific content the issue's own follow-up comment describes (`ResultsObserver`/`HistoryObserver` in `swiftdata-schema-designer.md`, `SE-0518`/`SE-0504`/`SE-0493` in `swift-concurrency.md`, exit tests/`Attachment` in `swift-testing-patterns.md`) is present in the current tree. No further action needed on items 1/3; this workplan entry covers **item 2 only**.

Item 2 resolved: **yes**, add a technical-currency check as a 5th `component-review` checklist item, alongside the existing type-choice/wiring-completeness/content-depth/trigger-gate-quality checks. Scope: applies to any component (not just `ios-engineering`), since `python-engineering`/`java-engineering` carry the identical risk (ported/adapted in the same reference-heavy style). The check flags *candidates* for re-verification — it does not attempt to verify currency itself (this skill's existing process is a local/static audit with no web access built in); resolving a flagged item is a separate, dedicated pass (of the kind already done for `ios-engineering` via a 9-agent parallel audit), not something `component-review` does inline.

**Acceptance criteria:** `component-review/SKILL.md` documents a 5th check ("e. Technical currency") with the same rigor as the existing four (what it looks for, how it's reported), and the report template in section 3 gains a `technical currency` line matching the `ok | n/a | flagged: ...` shape of the other four rows.

**Steps:**
- [ ] Add "**e. Technical currency.**" under component-review/SKILL.md's "2 — Per component, check four things" (renumber the heading to reflect five checks). Wording: flag any component content that states a specific external API, library/framework version, platform/OS version, or tool behavior as a factual claim that could plausibly have drifted since the component was last touched (grep for version numbers, "as of", named APIs/methods, deprecated-vs-current framework idioms) — report it as a candidate needing re-verification, not a fixed answer.
- [ ] Update the report template in section 3 to add a `technical currency : ok | flagged: <claim + file:line>` line.
- [ ] Leave sections 1 (Scope) and the other four checks untouched in this step — #43 will edit the Scope section's grep pattern separately.

**Files/areas likely touched:** `component-review/SKILL.md`.

---

### #43 — move all rules into top level rules component

**Resolved scope** (issue body was empty — resolved via interview): consolidate `git-rules/rule.md`, `documentation-rules/rule.md`, and `swiftui-rules/rule.md` into a single top-level `rules/` directory, one file per rule (`rules/git-rules.md`, `rules/documentation-rules.md`, `rules/swiftui-rules.md`). Each rule stays an independently named, independently installable/uninstallable component at today's exact granularity — no change to `ALL_COMPONENTS`, `is_known_component()`, or the per-component `install_<name>()`/`uninstall_<name>()` function names in `install.sh`/`uninstall.sh`. Only the *source file location* changes, from `<name>/rule.md` to `rules/<name>.md`. This becomes the required pattern for any future rule-type component — the one stated exception to this repo's general "each component gets its own top-level directory" convention.

Confirmed exact mechanism to change (read directly from the current scripts): `common.sh`'s `install_rule()` (lines 80–97) constructs the source path as `$SRC/$name/rule.md`. Changing that one function's two path references (the `cmp -s` staleness check and the `cp`) to `$SRC/rules/$name.md` is the entire install/uninstall-side change — `install.sh`/`uninstall.sh`/`components.sh` need **no edits at all**, since they only reference the component name, never the internal path `install_rule()` builds.

**Acceptance criteria:** `git-rules`, `swiftui-rules`, `documentation-rules` install to and uninstall from the exact same target (`~/.claude/rules/<name>.md`) as before, verified via a dry-run install/uninstall against a temp `CLAUDE_CONFIG_DIR` (this repo's own Definition-of-done check); no top-level `git-rules/`, `swiftui-rules/`, `documentation-rules/` directories remain; `README.md` and root `CLAUDE.md` accurately describe the new shared-directory layout as a stated exception, not silently; `component-review/SKILL.md`'s scope-detection grep pattern matches the new path.

**Steps:**
- [ ] `mkdir rules/`
- [ ] `git mv git-rules/rule.md rules/git-rules.md`; remove the now-empty `git-rules/` directory
- [ ] `git mv swiftui-rules/rule.md rules/swiftui-rules.md`; remove the now-empty `swiftui-rules/` directory
- [ ] `git mv documentation-rules/rule.md rules/documentation-rules.md`; remove the now-empty `documentation-rules/` directory
- [ ] `common.sh`: change `install_rule()` (the comment on the line above it, the `cmp -s` check, and the `cp` line) from `$SRC/$name/rule.md` to `$SRC/rules/$name.md`
- [ ] `README.md`: update the three component-table row links — `[\`git-rules\`](git-rules)` → `[\`git-rules\`](rules/git-rules.md)`, and the same for `swiftui-rules`/`documentation-rules`; update the intro sentence ("Each customization ... lives in its own top-level directory with its source file") and the "Adding a new component" walkthrough to state the rule-type exception
- [ ] Root `CLAUDE.md`: update "Each component lives in its own top-level directory with its source file" (in the "Claude Code" section) to carve out the rule-type exception; update the example paths in "Choosing a component type" (currently `swiftui-rules/rule.md` / `git-rules/rule.md`) to `rules/swiftui-rules.md` / `rules/git-rules.md`
- [ ] `component-review/SKILL.md`: change the scope-detection `git diff` pattern from `'*/rule.md'` to `'rules/*.md'`
- [ ] `harness-scaffold/references/this-repo-as-template.md`: update the line describing "each directory's source file ... `rule.md` ..." to note rules are the one shared-directory exception, so a from-scratch scaffold of a *new* target harness doesn't copy the wrong invariant
- [ ] Dry-run: `CLAUDE_CONFIG_DIR=<temp> ./install.sh git-rules swiftui-rules documentation-rules`, confirm files land at `<temp>/rules/<name>.md`, then `./uninstall.sh` the same three and confirm clean removal

**Files/areas likely touched:** new `rules/` directory; removal of `git-rules/`, `swiftui-rules/`, `documentation-rules/`; `common.sh`; `README.md`; root `CLAUDE.md`; `component-review/SKILL.md`; `harness-scaffold/references/this-repo-as-template.md`.

---

### #22 — Enhance prepare-pr, write-adr, doc-sync with dotcopilot-equivalent capabilities

**Resolved scope (final, after direct interview on 2026-07-23):** research subagents first read the actual dotcopilot source (`/Users/connor/src/ai-configs/dotcopilot`) to find concrete mechanics; the user was then interviewed against those findings, sub-item by sub-item, to decide what actually gets pulled in. Net result: **doc-sync** gets a README-deepening mode only (no separate onboarding file, no API-reference/OpenAPI generation at all); **prepare-pr** gets only the change-walkthrough section (no scorecard); **write-adr** gets the full trade-off/diagram/checklist treatment, diagram always included; **tdd-writer** is deferred entirely, not built in this pass.

Since API-reference generation was dropped, the dependency originally planned between doc-sync and prepare-pr (prepare-pr delegating API-doc regen to doc-sync) no longer exists — all three remaining sub-items are fully independent.

#### #22a — doc-sync: README-deepening mode

**Resolved scope:** doc-sync gains a new mode that deepens `README.md` in place — **not** a separate `docs/onboarding.md` file, and **not** any API-reference/OpenAPI generation (both explicitly dropped after interview). Add a new mode value, `deepen` (alongside the existing `fix`/`report`), invoked as `/doc-sync deepen [range] [paths...]`.

In `deepen` mode: explorer role surveys the codebase the same way dotcopilot's `survey_codebase.sh` does conceptually (language/framework/directory structure/entry points/config/git history), but via Glob/Grep/Read/git commands rather than a bundled script — consistent with doc-sync's existing "read and reason" pattern rather than dotcopilot's regex/script-based one. Planner turns the findings into additions for four new `README.md` sections (only the ones not already adequately covered): **Architecture Overview** (an ASCII diagram from real import relationships, plus a request/data-flow trace through one real path — for this repo specifically, that's tracing one component's actual install → invocation → uninstall path, not a web request), **Common Development Tasks** (e.g. this repo's own "adding a new component" walkthrough, verified against `components.sh`/`install.sh`/`uninstall.sh`), **Gotchas and Non-Obvious Things** (a table of genuine traps — real ones, not generic advice — verified by reading the actual code, e.g. things like the destructive-command backup mechanics already documented in `common.sh`'s comments), and **Key Files to Read First** (an ordered list with one-sentence rationale each). doc-writer applies these as new sections to the existing `README.md` (never a second file). Reviewer runs a checklist adapted from dotcopilot's 12-item onboarding-guide gate: every file path exists, every command is verified against real config, the diagram reflects real structure, no placeholder/speculative content, gotchas are genuine (not restatements of "read the docs"), key-files are ordered for progressive understanding.

Deliberately not porting `verify_routes.py` or any API-doc-generation capability — dropped entirely, not deferred, per the interview.

**Acceptance criteria:** `/doc-sync deepen` adds/refreshes the four new sections in `README.md` directly (no new file created), each section's claims traced to real files/commands the reviewer role verified; existing README sections (intro, quickstart, component table) are left alone unless they're independently stale (that's still the existing `fix`/`report` modes' job, not `deepen`'s).

**Files/areas likely touched:** `doc-sync/SKILL.md` (add the `deepen` mode + its procedure branch), `doc-sync/explorer-agent.md`, `doc-sync/planner-agent.md`, `doc-sync/doc-writer-agent.md`, `doc-sync/reviewer-agent.md` (extend each role's prompt to cover this mode).

---

#### #22b — prepare-pr: change walkthrough only

**Resolved scope:** add an optional "Change Walkthrough" section to the drafted PR body — layer-by-layer (skip layers with no changes), ≤20-line verbatim snippets sourced only via the Read tool (never typed from memory, matching this repo's own no-fabrication convention). Included only when the diff touches 3+ files or crosses an architectural-layer boundary — this repo's own existing bar for "non-trivial" (the same threshold `CLAUDE.md`'s spec-first-planning exception clause uses). Trivial/single-file PRs keep today's plain Summary-only body.

**Dropped after interview, not part of this scope:**
- **Scorecard** (4-category Architecture/Security/Log Hygiene/Test Coverage pass/warn/fail table) — dropped as redundant with what the existing post-open `review` skill already reports per-finding, and this repo's own component-library shape doesn't have "architecture layers"/"log hygiene" in the way a typical target app repo does; the scorecard's value would only show up when prepare-pr is installed elsewhere, which wasn't judged worth the added complexity here.
- **API-doc regen** — dropped along with doc-sync's API-reference mode (see #22a); no delegation needed since neither side implements it.
- **Refactor-planner escalation** — out of scope; would require an entirely new stand-alone `refactoring-planner` skill, not a prepare-pr tweak. Candidate for its own future issue if ever wanted.

**Acceptance criteria:** PR bodies for 3+-file or cross-layer changes include a verified (Read-tool-sourced) Change Walkthrough section; single-file/trivial PRs are unaffected; no scorecard, no API-doc-regen logic, no refactor-planner invocation anywhere in this skill.

**Files/areas likely touched:** `prepare-pr/SKILL.md`.

---

#### #22c — write-adr: trade-off-analysis routing, bundled diagram, quality checklist

**Resolved scope:** dotcopilot splits this capability across a separate `architect` agent (trade-off engine + diagram) and `adr-writer` (drafting + its own checklist) + a thin prompt (routing glue). This repo has no `architect`-equivalent component and shouldn't gain one just for this — the trade-off analysis needs live `AskUserQuestion` round-trips with the user, which a spawned subagent can't do (matching `write-adr`'s own existing stated reason for running inline rather than as a subagent) — so all of the following folds directly into `write-adr/SKILL.md` itself:

- **Routing, added as the first step:** determine whether the decision is still open or already made (ask if unclear from the invocation).
  - **Open** → run a trade-off-analysis step: clarify evaluation criteria with the user (ask what matters, or infer from context); compare **at least two** alternatives via a criteria-matrix table (criteria as rows, options as columns, per-criterion winner marked) — if the user supplies fewer than two, propose common alternatives from a bundled decision-domains reference and confirm before proceeding; recommend one option, state why, and acknowledge when a different priority would favor the other.
  - **Already made** → ask exactly one probing question before drafting: *"What alternatives did you consider, and what made you choose this?"*
- **Bundled diagram — confirmed always include (interview outcome):** every ADR gets a plain-text ASCII box diagram of the chosen design, unconditional — not gated on complexity. Rule ported verbatim: never diagram from assumption — every box/arrow must correspond to real code or a well-defined proposal. No separate diagramming component is introduced — this is a short, self-contained convention written inline in `write-adr`, not extracted into a shared skill for a single consumer.
- **Quality checklist**, added as a self-check before delivering (verbatim-portable, fully stack-agnostic per the research): title is an imperative phrase naming the decision, not the problem; Context doesn't foreshadow the decision; Context names the competing forces; Decision is stated unambiguously in the first sentence; Rationale ties back to Context's forces; revisit triggers are included; ≥2 alternatives with concrete rejection reasons; Consequences include ≥1 negative/trade-off; **Status defaults to `Proposed` unless the user has explicitly confirmed the decision is final (`Accepted`)** — this replaces the current hardcoded `Accepted` default in the template; Date present and correct; no stray placeholder text; Related Decisions links prior ADRs that constrain or are affected.
- **Decision-domains reference:** add `write-adr/references/decision-domains.md`, a stack-agnostic lookup table (Datastore, Message queue, API style, Auth, Deployment, Service communication, Frontend state, Caching, Architecture pattern, Monorepo/polyrepo, Observability, Task queue), used only when the user hasn't supplied ≥2 alternatives themselves. Explicitly **not** porting dotcopilot's Python-specific `python/decision-domains.md` extension in this pass — a per-language decision-domains reference can be added later the same way `python-engineering`/`java-engineering` were, but isn't part of this resolved scope.

**Acceptance criteria:** invoking `write-adr` for an open decision surfaces a criteria-matrix comparison and a recommendation before drafting; invoking it for an already-made decision asks the single probing question first; every produced ADR includes an ASCII diagram and passes the 12-item checklist before being shown to the user; `Status` is no longer unconditionally `Accepted`.

**Files/areas likely touched:** `write-adr/SKILL.md` (extended), new `write-adr/references/decision-domains.md`.

---

### Deferred: tdd-writer (new skill) — not in this workplan

Dotcopilot's `tdd-writer` agent (10-section Technical Design Document, gated ADR/diagram/changelog steps, Python/Java implementation-appendix skills) was researched in full and would map to one new stack-agnostic `tdd-writer` skill in this repo (core `SKILL.md` + `references/python-appendix.md` + `references/java-appendix.md`, internally invoking `write-adr` when its 2-of-4-yes test passes, no separate installed components for the smaller delegate steps dotcopilot splits out). After interview, the user chose to **defer this entirely** rather than build it now — it's the largest, most speculative addition of the four, with no existing analog in this repo. Recommend filing it as its own separate GitHub issue (carrying forward the research findings above) rather than reviving it inside this workplan later.

## Decisions made during planning

- Issue #43 had an empty body → resolved to: one shared top-level `rules/` directory, one file per rule, same individual install/uninstall granularity as today — the single stated exception to this repo's "one top-level directory per component" convention.
- Issue #24's items 1 and 3 were already complete → verified directly against `main`'s commit history rather than trusting the issue comment's "uncommitted as of this comment" note, which was stale. Item 2 resolved to: yes, add as a 5th `component-review` check, flagging candidates rather than resolving them inline.
- Issue #22's dotcopilot-porting decisions were made in two passes: research subagents first read dotcopilot's actual source to find concrete mechanics, then the user was interviewed directly against those findings (not left to a future execution session) to decide what to actually pull in — see [[interview-before-porting-external-content]] for why porting decisions specifically get a live interview rather than being resolved from research alone.
- doc-sync's onboarding capability was redefined mid-interview from "separate `docs/onboarding.md`" to "deepen the README in place" — reasoning: a second artifact describing overlapping project structure/architecture content is itself a doc-sync-relevant drift risk (two docs to keep in sync instead of one), and this repo's own README already serves the onboarding-doc role reasonably well as a single artifact.
- doc-sync's API-reference/OpenAPI generation was dropped entirely (not deferred) — this repo is a Claude-Code component library with no REST API surface of its own, and the capability's value is entirely for other target projects doc-sync gets installed into; not judged worth building speculatively in this pass.
- prepare-pr's scorecard was dropped (changelog-walkthrough kept) — judged redundant with the existing `review` skill's per-finding output, and the 4-category structure (Architecture/Security/Log Hygiene/Test Coverage) doesn't map cleanly onto this repo's own shape.
- prepare-pr's API-doc-regen delegation to doc-sync was dropped along with doc-sync's API-reference mode — no longer applicable once that mode doesn't exist.
- write-adr's bundled diagram was confirmed unconditional (always included) rather than gated on complexity, after direct interview — avoids an extra judgment call, and ADRs specifically benefit from a fixed lightweight visual.
- tdd-writer was deferred entirely after interview (not scoped down, not guessed at) — it's the largest, most speculative addition with no existing analog in this repo; the research is preserved above for whenever it's picked up as its own issue.
- write-adr and tdd-writer's (deferred) trade-off/diagram logic was resolved to live inline in each skill's own body (no new `architect`-equivalent agent, no shared `ascii-diagram` skill) because the interview step requires live `AskUserQuestion`, which a spawned subagent can't do, and because a single consumer (write-adr) doesn't justify extracting a shared component.
