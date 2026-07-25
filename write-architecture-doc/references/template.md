# Architecture Document Skeleton

Stack-agnostic fill-in template — one block per section of the target document. Each block has
a *Purpose* (why the section exists), *What to gather* (the research checklist from `SKILL.md`
step 2 that feeds it), and a *Skeleton* (heading + Mermaid placeholder to fill in). Omit a
section outright rather than leaving it thin if the target system genuinely has nothing for it
(see the two explicit omission rules in `SKILL.md` step 3, for Schema/Version Evolution and
Navigation & State Model).

## Overview

**Purpose:** orient a reader who has never seen this system in under a minute.

**What to gather:** one or two sentences on what the system does and who its users are; a
tech-stack table (UI, persistence, sync/networking, background processing, testing, …) mapping
each layer to its concrete technology; whether third-party dependencies exist and roughly how
many/which are load-bearing; 3–6 bullets on the system's defining characteristics — the things
that would surprise someone coming from a "typical" system of this kind.

```markdown
## Overview

<one-to-two-sentence description of purpose and users>

| Layer | Technology |
|---|---|
| <layer> | <technology> |

**Key characteristics**

- <characteristic>
```

## Architecture Principles

**Purpose:** name the load-bearing design rules a contributor must know before making changes,
that aren't obvious from reading any single file.

**What to gather:** a rule applied consistently across many files but never written down —
e.g. "no direct writes to the database outside one module," "every mutation must be undoable,"
"every service is composed once at startup." Doc comments explaining *why* a pattern exists
(not just what it does) are strong signal.

```markdown
## Architecture Principles

| Principle | What it means in this codebase |
|---|---|
| <principle name> | <one-line explanation, with a file reference if concrete> |
```

## System Context Diagram

**Purpose:** show the system's boundary — what's inside it versus every external system it
talks to.

**What to gather:** the single user/actor (or actor types, if more than one); every external
system crossed at runtime (databases the app doesn't own, third-party APIs, push/notification
services, file/storage systems, other internal services); for each edge, one verb phrase
describing the interaction.

```markdown
## System Context Diagram

\`\`\`mermaid
flowchart LR
    Actor(("<actor>"))
    subgraph Boundary["<system name>"]
        App["<application>"]
        Store[("<primary data store>")]
    end
    External1["<external system>"]

    Actor -->|uses| App
    App -->|reads / writes| Store
    App -->|<verb>| External1
\`\`\`

- <bullet calling out anything non-obvious about the boundary, e.g. "no backend server exists">
```

## Layered Architecture Diagram

**Purpose:** show how responsibility divides top-to-bottom (or side-to-side) — presentation,
orchestration, domain logic, persistence — and which layers cross-cutting services attach to.

**What to gather:** the layers this codebase actually has (don't force a canonical N-tier shape
if it doesn't fit); for each layer, its real responsibility and what it's forbidden from doing
(e.g. "presentation never contains business rules"); where cross-cutting services attach.

```markdown
## Layered Architecture Diagram

\`\`\`mermaid
flowchart TB
    subgraph Presentation["<layer name — path>"]
        P1["<component>"]
    end
    subgraph Orchestration["<layer name — path>"]
        O1["<component>"]
    end
    subgraph Domain["<layer name — path>"]
        D1["<component>"]
    end
    Persistence[("<data store>")]

    Presentation --> Orchestration
    Orchestration --> Domain
    Orchestration --> Persistence
\`\`\`

- <one bullet per layer: what it owns, what it must never do>
```

## Module & Package Structure

**Purpose:** map physical code organization (packages/modules/targets) to logical
responsibility and dependency direction — the thing a build-system config file encodes but
rarely explains.

**What to gather:** every top-level module/package/target and its one-line responsibility; its
dependencies, and — more importantly — what's *not allowed* to depend on it, if enforced (e.g.
a platform-neutral domain package that must never import a UI framework).

```markdown
## Module & Package Structure

| Module | Type | Responsibility | Depends on |
|---|---|---|---|
| <module> | <library/app/test target> | <responsibility> | <dependencies, or "—"> |

\`\`\`mermaid
flowchart LR
    ModuleA --> ModuleB
\`\`\`
```

## Data Model

**Purpose:** the authoritative reference for every persistent entity, its fields, and how
entities relate — the section most readers return to repeatedly.

**What to gather:** every persistent entity's fields (name, type, nullability), and any field
whose meaning isn't obvious from its name; every relationship's cardinality (one-to-one/
one-to-many/many-to-many), optionality on each side, and delete/cascade behavior; any embedded/
value types that live inside an entity but aren't independently persisted.

```markdown
## Data Model

### Entity-Relationship Diagram

\`\`\`mermaid
erDiagram
    ENTITY_A ||--o{ ENTITY_B : "<relationship verb>"
    ENTITY_A {
        type id PK
        type field
    }
\`\`\`

### Relationship & Delete-Rule Reference

| Relationship | Delete rule | Behavior |
|---|---|---|
| <A ↔ B> | <cascade/restrict/nullify/etc> | <one-line description> |

### Entity Field Reference

**<Entity>**

| Field | Type | Notes |
|---|---|---|
| <field> | <type> | <notes, only if non-obvious> |

### Embedded Value Types

| Type | Owner | Fields | Notes |
|---|---|---|---|
| <type> | <owning entity> | <fields> | <notes> |
```

## Schema / Version Evolution

**Purpose:** show the lineage of breaking data-shape changes so a reader can understand why
migration code exists and what it does. **Omit this section entirely** if the system has never
had a breaking schema change.

**What to gather:** each schema/version boundary, oldest to current, and what changed at each
one; the migration mechanism used (framework-provided automatic migration vs. a custom/manual
stage) and why a custom stage was needed where one was; links to the decision record for each
boundary, if one exists.

```markdown
## Schema / Version Evolution

\`\`\`mermaid
flowchart LR
    V1["<version 1>\n<what it looked like>"] -->|"<migration mechanism>"| V2["<version 2>\n<what changed>"]
\`\`\`

| Version | Change | Migration mechanism | Decision record |
|---|---|---|---|
| <version> | <change> | <mechanism> | <link, or "—"> |
```

## Sequence Diagrams

**Purpose:** trace the 4–6 most important workflows end to end, so a reader can see exactly
which components talk to each other and in what order.

**What to gather, per workflow:** the trigger (user action, scheduled job, incoming event);
every component/service touched, in call order; any branching (success/failure, optional side
effects like undo or notifications).

```markdown
### <Workflow Name>

<one-line description of what this workflow accomplishes and why it's included>

\`\`\`mermaid
sequenceDiagram
    actor User
    participant Component
    User->>Component: <trigger>
    Component->>Component: <step>
    Component-->>User: <result>
\`\`\`
```

Repeat once per workflow. Use `alt`/`opt`/`loop` blocks for branching and repetition — every
opener needs a matching `end`.

## Navigation & State Model

**Purpose:** document how the system moves between screens/views/pages or major states.
**Omit or retitle this section** ("State Model") if the system has no UI navigation concept —
a stateless backend service, a workflow/job engine — rather than forcing the UI framing onto
something that isn't one.

**What to gather:** the top-level areas/screens/states and what triggers a transition between
them; any centralized navigation/state-owning object versus per-screen local state; any "jump"
transitions that skip the obvious path (deep links, cross-cutting shortcuts).

```markdown
## Navigation & State Model

\`\`\`mermaid
flowchart TD
    AreaA --> AreaB
    AreaA -.->|<shortcut/deep-link>| AreaC
\`\`\`

| Route/state | Owner | Triggers |
|---|---|---|
| <route> | <owning module> | <cases> |
```

## Cross-Cutting Concerns

**Purpose:** one table covering every concern that spans multiple layers and would otherwise be
scattered across the doc — logging, error handling, auth, caching, background work, etc.

**What to gather:** for each concern, the mechanism used and the key file(s) implementing it;
prefer linking to a decision record over re-explaining the reasoning inline.

```markdown
## Cross-Cutting Concerns

| Concern | Mechanism | Key files |
|---|---|---|
| <concern> | <mechanism> | <file path(s), decision record link> |
```

## Testing Architecture

**Purpose:** map every test suite/target to what it covers and the exact command to run it.

**What to gather:** every distinct test target/suite/package; what each one actually covers
(unit/integration/end-to-end, and of what); the literal command (or IDE action) to run it,
including any prerequisite (a running emulator/simulator, a database, environment variables).

```markdown
## Testing Architecture

| Target | Scope | Framework | How to run |
|---|---|---|---|
| <target> | <scope> | <framework> | <command> |
```

## Related Decision Records

**Purpose:** index every architecture decision record (ADR/RFC/design doc) referenced elsewhere
in the document, so a reader can jump straight to the reasoning behind a specific choice.

**What to gather:** every decision record referenced anywhere else in the document, and a
one-line summary of each decision (not its full reasoning — that's what the link is for).

```markdown
## Related Decision Records

| Record | Decision |
|---|---|
| [<slug>](<path>) | <one-line summary> |
```
