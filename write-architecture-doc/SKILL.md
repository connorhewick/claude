---
name: write-architecture-doc
description: >
  Produce a production-quality architecture document for a codebase or repo — system context,
  layered architecture, module/package structure, a data model with an entity-relationship
  diagram, schema/version evolution, sequence diagrams for key workflows, a navigation/state
  model, cross-cutting concerns, testing architecture, and an index of related decision
  records. Triggers for: "document the architecture", "create architecture diagrams",
  "architecture doc for this repo", "system context diagram", "layered architecture diagram",
  "data model diagram", "entity relationship diagram", "sequence diagrams for this system", "ERD
  for this codebase". Do NOT trigger for a single decision record (that's `write-adr`),
  product/requirements scoping (that's `write-prd`), a single feature's design before
  implementation (that's `write-tdd`), or fixing drift between existing docs and code (that's
  `doc-sync`).
argument-hint: >
  [target repo or scope, if not the current one]
---

## 1. Confirm scope & conventions before writing

Two decisions are the user's to make, not yours — ask before drafting anything:

1. **Diagram notation.** Mermaid (recommended: renders natively on GitHub/GitLab, no extra
   tooling, stays readable in diffs) vs. PlantUML/C4 (if the org already standardizes on one).
2. **File placement.** Match the target repo's existing documentation convention (a flat
   `docs/` folder, a `docs/architecture/` directory, a wiki). Propose one if none exists.

## 2. Research the codebase

Work through these in order — each feeds a specific section of the template
(`references/template.md`):

1. **Entry points.** Read the repo's root docs (README, CONTRIBUTING, package/build manifests)
   for tech stack, module/package boundaries, and build/run/test commands.
2. **Persistent/domain entities.** Find the ORM/database models (or equivalent domain types);
   for each, its fields, its relationships to other entities, their cardinality, and
   delete/cascade behavior.
3. **Cross-cutting services.** Anything composed once and shared system-wide: navigation/
   routing, config/settings, logging, auth, sync, notifications, feature flags, caching.
4. **Representative workflows.** Pick the 4–6 most important multi-step operations — the ones a
   new engineer would need to understand first — and trace each end-to-end: trigger →
   orchestration → persistence → side effects (notifications, sync, undo, …).
5. **Schema/version history**, only if the system has been through a breaking data-shape
   change; find the migration mechanism and reconstruct the lineage oldest-to-current. Skip
   this research step entirely if there's no such history.
6. **Test suites.** Map each test target/suite/package to what it actually covers and the exact
   command to run it.
7. **Existing decision records** (ADRs/RFCs/design docs) touching anything found above — link
   to them, don't re-derive or duplicate their reasoning.

## 3. Draft the document

Use `references/template.md` — a 12-section skeleton (Overview, Architecture Principles,
System Context Diagram, Layered Architecture Diagram, Module & Package Structure, Data Model,
Schema/Version Evolution, Sequence Diagrams, Navigation & State Model, Cross-Cutting Concerns,
Testing Architecture, Related Decision Records). Every generated doc file gets a Table of
Contents after the title, with anchor links matching each heading (lowercase, spaces →
hyphens, punctuation stripped).

Style bar, apply throughout:

- One sentence of context per section, maximum two, before a table/bullet list/diagram — never
  a paragraph where a table would do.
- Every diagram gets a one-line caption or short bullet list underneath explaining what it
  shows, not restating it.
- Every table row should be information the reader would otherwise have to open source code to
  find — skip anything obvious from the entity/column name itself.
- Reference decision records by short descriptive slug (`ADR-0003-payment-retry-policy`), never
  by bare number — numbers collide across branches and are meaningless out of context.
- Omit the Schema/Version Evolution section entirely if the system has never had a breaking
  schema change — an empty migration story isn't worth documenting.
- Omit or retitle Navigation & State Model to "State Model" for a system with no UI navigation
  concept (a stateless backend service, a workflow/job engine) — don't force the UI framing
  onto something that isn't one.

## 4. Self-check before delivering

- [ ] Every diagram renders without error in the chosen notation (verify via a live preview,
      not by eye)
- [ ] Every Table of Contents anchor matches its heading's actual generated slug
- [ ] Every entity/relationship/delete-rule claim in the Data Model section has been checked
      directly against the code that defines it, not inferred from a diagram or a teammate's
      description
- [ ] Every internal link (to another section, another doc, a source file) resolves
- [ ] No section is a wall of prose — if a section reads as more paragraph than table/bullet/
      diagram, restructure it before calling the doc done
- [ ] Every decision record is referenced by descriptive slug, not bare number

## Rules

- This is a documentation task, not an implementation task — never modify application code
  while producing this document.
- Don't invent entities, relationships, or workflows that aren't in the code — every diagram
  element must correspond to something actually read, the same rule `write-adr` applies to its
  own diagrams.
- For the full per-section skeleton (purpose, what to gather, Mermaid skeleton — one block per
  section), see `references/template.md`.
