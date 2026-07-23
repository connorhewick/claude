---
name: write-tdd
description: >
  Produce a Technical Design Document (TDD) for a feature or service before implementation
  begins — API contract, data model, service design, and any resulting architecture decisions,
  bundled as one design artifact. Triggers for: "design this feature", "write a TDD", "technical
  design document for X", "design the API and schema for X", "spec out the backend for this
  feature". Do NOT trigger for pre-code requirements/problem framing (that's `write-prd`), for a
  single standalone decision with no surrounding API/data-model design (that's `write-adr`), for
  a trivial single-endpoint change with no real design surface to document, or for a single
  schema/query/endpoint implementation request with no broader multi-section design need (that's
  `python-engineering`/`java-engineering`/`ios-engineering` directly).
argument-hint: >
  [feature-name]
---

Senior architect producing a first-iteration Technical Design Document for a feature — a
backend's API contract, data model, and service design, and/or a client's screen/navigation/state
design and its data consumption. Which of those actually apply depends on the feature — a
backend-only feature has no UI to design; a UI-only feature (a new screen, a navigation change)
has no API/data model to design. Design only: no service-layer code, no repository methods, no
view/view-model implementations, no tests. Stack-agnostic core; loads a stack-specific appendix
(see "Loading a stack-specific appendix" below) only when the target codebase is Python, Java, or
Swift/iOS.

## 1 — Project Discovery (once per invocation)

- Detect stack/framework from manifests (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`,
  `pom.xml`/`build.gradle`, `Package.swift`/`.xcodeproj`/`.xcworkspace`) and the existing
  architecture (layered/hexagonal/MVC/CQRS/event-driven, or MVVM/MV/TCA/VIPER for an iOS client)
  from directory structure.
- Read this project's own `CLAUDE.md`/`ARCHITECTURE.md` if present, for stated conventions.
- Check `docs/prd/` for a prior `write-prd` output and `docs/adr/` for prior `write-adr` output
  relevant to this feature — read them if present. Treat accepted ADRs as binding: if the feature
  being designed would conflict with one, don't silently diverge — record the conflict under Open
  Questions and name which ADR it's in tension with.
- Note any existing design-doc directory already in use (`docs/tdd/`, `docs/design/`,
  `docs/rfcs/`) and match its numbering/formatting rather than introducing a second convention.

## 2 — Plan-then-confirm gate

Before drafting anything, state what Discovery found and what you expect the TDD to need — new
tables? modified existing behavior? does this look ADR-worthy (see the gate in step 5)? — then
wait for the user to confirm before writing.

## 3 — Write the TDD

Save to `docs/tdd/NNNN-slug.md`, where `NNNN` is the next unused four-digit number in `docs/tdd/`
(start at `0001` if the directory doesn't exist yet) and `slug` is a short kebab-case name for the
feature. Use this template — every section states real content or an explicit "N/A", never a
placeholder left unfilled:

```markdown
# NNNN. <Feature name>

Date: <YYYY-MM-DD>

## 1. Overview

<Problem statement, goals and non-goals, background — why this feature, and what it explicitly
does not cover.>

## 2. Architecture Context

<Plain-text ASCII diagram showing where this feature sits relative to existing components. See
the diagram rule below.>

## 3. API Contract

<Endpoints, request/response schemas, status codes, error responses. Concrete, not illustrative —
match the target codebase's actual framework conventions.>

## 4. Data Model

<New tables or schema changes, with an ER-style diagram if there's more than one new table.>

## 5. Service & UI Design

<For a backend/service feature: layer responsibilities for the new/changed code, the sequence of
calls across layers, error handling strategy. For a UI-heavy client feature (iOS, web frontend):
which screens/views exist and how they're composed, the navigation flow between them, what state
each view/view-model owns and where it comes from (network/local/derived), and the
loading/error/empty states the UI must handle. A feature can need either, both, or (for a
pure-UI feature with no API/data-model surface) only the UI half — cover whichever this feature
actually has; don't force service-layer framing onto a screen-only change.>

## 6. Non-Functional Requirements

<Performance, security, observability, and (for a UI feature) accessibility expectations. "N/A"
if this feature has none beyond the codebase's existing defaults.>

## 7. Migration & Rollout

<Data migration steps, rollout strategy, breaking changes. "N/A" if this is a purely additive
feature with no migration surface.>

## 8. Architecture Decisions

<Either "None — see step 5 gate" or the resulting ADR reference(s) if the gate below passed.>

## 9. Open Questions

<Anything Discovery couldn't resolve, including any ADR-conflict flagged in step 1. "None" if
there truly aren't any — don't invent one to fill the section.>

## 10. Appendices

### A. Glossary

<Domain terms a reader would need. Omit this subsection if the feature introduces none.>

### B. References

<Links to the PRD/ADRs this TDD builds on, prior art, or external references. "None" if there
aren't any.>
```

## 4 — Diagram rule (same rule as `write-adr`, always included, never assumed)

The Architecture Context diagram (and the Data Model one, if used) is unconditional — every TDD
gets one, not gated on how complex the feature is. But never diagram from assumption: every box
and arrow must correspond either to real code you've actually read, or to a well-defined proposal
already discussed with the user in this session.

## 5 — Architecture Decision gate

After drafting sections 1–7, check this feature against the following. If **two or more** are
true, this decision is ADR-worthy:

- [ ] Affects more than one service/area of the codebase
- [ ] Introduces a pattern new to this codebase
- [ ] Would be hard to reverse once built
- [ ] Needs team consensus, not just this author's call

If it passes, invoke this repo's own `write-adr` skill directly to draft the ADR — don't
duplicate its trade-off-analysis or drafting logic here. Reference the resulting ADR under
section 8; otherwise section 8 just says "None — see step 5 gate."

## 6 — Optional: what changes for existing behavior

If this feature modifies behavior that already exists (not purely additive), add a short note —
a few sentences, not a full changelog document — under section 1's Background or section 7's
Migration & Rollout, whichever it more naturally belongs to. This repo has no separate
changelog-generation component to delegate to; keep this note brief rather than inventing one.

## 7 — Self-review before handoff

Before showing the finished TDD to the user, check it against every item below:

- [ ] Every API endpoint in section 3 has a corresponding data path in section 4 (or explicitly
      doesn't need one)
- [ ] Every new table in section 4 maps to at least one API field or operation in section 3
- [ ] Error scenarios are covered wherever they apply — API-level (section 3) and/or
      service-level/UI-level (section 5) — matching whichever sections aren't "N/A"
- [ ] Non-Functional Requirements and Migration & Rollout are either filled in or explicitly
      "N/A" — never left blank
- [ ] The Architecture Decision gate (step 5) was actually run, not skipped
- [ ] No placeholder text remains anywhere in the document

## 8 — Optional: Implementation Kickoff appendix

Only add this — as the last section of the document, numbered `## 11` (or `## 12` if a
stack-specific appendix, below, is also included) — for a full new-entity/endpoint feature, or
when the user explicitly asks for one. Skip it for exploratory or partial designs, or anything
still pending architect-level review.

Contents: a table of files to create (path, purpose), and which of this repo's own implementation
skills to invoke next — `python-engineering`, `java-engineering`, or `ios-engineering`, whichever
matches the detected stack — pointing at the specific reference file within that skill most
relevant to this feature's shape (e.g. "read `python-engineering/references/
fastapi-service-generator.md` first"). This hands off design to implementation without the
implementing session needing to re-read the whole TDD — it's a pointer, not a restatement of
sections 3–5.

## Loading a stack-specific appendix

If Discovery detected Python, Java, or Swift/iOS as the primary stack, append one more section
right after Appendices — `## 11. <Language> Implementation Notes` — built from the matching
reference file below. If an Implementation Kickoff section (above) is also included, it comes
after this one and shifts to `## 12`. For any other detected stack (or none detected), skip this
section entirely — don't guess at framework-specific detail for a stack this skill has no
reference for.

| Detected stack | Read |
|---|---|
| Python (FastAPI/SQLAlchemy) | `references/python-appendix.md` |
| Java (Spring Boot/JPA) | `references/java-appendix.md` |
| Swift/iOS | `references/ios-appendix.md` |

These appendix references translate the already-finished, framework-agnostic sections 3–5 into
concrete signatures — not implementations. Never invent anything beyond what's already in the
TDD; if the appendix would need content the core TDD doesn't have, that's a gap in the TDD
itself — go back and fix section 3, 4, or 5, don't patch it over in the appendix.

**iOS is a client, not a server — sections 3/4 mean something different there, and section 5 can
be its primary content.** For a Python/Java target, sections 3 (API Contract) and 4 (Data Model)
describe what the *server* exposes and stores, and section 5 covers server-side service/layer
design. For an iOS target, the app is usually the API's *consumer*: section 3 becomes the
contract the app calls (not serves), section 4 becomes local persistence (SwiftData) only if the
feature caches or stores data on-device, and section 5 covers the app's own screen/navigation/
state design — for a UI-only iOS feature with no API/data-model surface, section 5 is where all
the real design content lives, with sections 3–4 both "N/A". `references/ios-appendix.md`
explains exactly how each core section maps — read its intro before assuming the same mapping as
the backend appendices.

## Error handling

- **Vague or missing requirements**: ask before drafting — don't guess at scope. If this looks
  like it needs requirements-level discovery rather than technical design, say so and point at
  `write-prd` instead of proceeding.
- **Feature too large for one TDD**: recommend splitting into multiple TDDs along natural
  service/domain boundaries rather than producing one sprawling document.
- **Requirements change mid-draft**: re-run only the affected sections, don't silently patch
  around a stale earlier one.
- **Codebase convention conflicts with best practice**: follow the codebase's existing convention
  and flag the tension under Open Questions — don't unilaterally introduce a new pattern.
