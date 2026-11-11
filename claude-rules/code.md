---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte,py,swift,m,mm,go,rs,java,kt,kts,scala,rb,c,h,cc,cpp,cxx,hh,hpp,cs,php,dart,lua,zig,ex,exs,sh,bash,zsh,sql}"
---

# Writing code

Loads when a code file is read.

## Design

- **Extend rather than modify where the behaviour is published or the call sites are out of
  reach** (`contracts.md` says which). Inside that boundary, change the code in place: a new path
  beside a working one leaves two, and the old one never goes away.
- **No abstraction ahead of its consumer.** Before adding an interface or generic, write the
  signature of the code that will accept it. One implementer and no test seam is speculative.
- **Presentation chooses what to show; derivation is a rule.** Filtering a list in a view is
  selection. Dates, money, progress and any maths with cases are rules: put them where they can
  be tested as pure functions.

## Errors

- **Fail closed.** When a check can't complete, the answer is no.
- **Catch where you can act**: retry, fall back, translate, refuse. Never swallow — an empty
  `catch`, or a default returned from one, hides a defect.

## Concurrency and time

- **Anything that can be retried will be.** A write a client can repeat is idempotent or carries
  an idempotency key.
- **Read-then-write across a boundary is a race.** Use the store's atomic form: conditional
  update, unique constraint, compare-and-swap.
- **Every wait has a timeout.** A retry needs backoff, jitter and a cap, and only on a failure
  that could succeed later. Never sleep to synchronise; wait on the condition.

## Debugging

- **Diagnose before editing.** Reproduce on demand from a command, on the smallest input. If it
  won't reproduce, say so and label conclusions as inferred.
- **One hypothesis at a time**, stated as *X causes the symptom because Y*, with a check that
  could falsify it. Three ruled out: stop and re-plan.
- **Fix where the wrong value is created, not where it is noticed.** The reproduction becomes
  the test. Report symptom, cause, fix, test, and what was ruled out.

## Logging

- Log at the boundary, not in the loop: entry, exit with outcome and duration, each external call.
  Structured fields carrying the correlation and entity identifiers.
- A number you alert on is a metric and a fact you must prove is an audit record. Neither is a
  log line.

## Comments

The default is no comment. One earns its place only by stating a **contract or invariant whose
breakage a reviewer could not see in the diff**: a precondition, a unit, an ordering, a data or
schema constraint, framework behaviour that can't be re-derived, or why an attractive fix is
wrong. The test: could someone change this code correctly-looking and break something because
the comment was absent? If not, delete it.

- **Doc comment**: a caller contract, judged by content, not visibility. Never summarise a type,
  property or function by what its name and signature already say. A private member gets one only
  when the rest of its file is the caller that could break the invariant.
- **Line comment**: the *why*, and only where deleting it would invite a wrong fix.
- **Delete** a comment that restates the code, orients the reader, narrates history (git is the
  record), is true but not worth the lines, or is stale. Also delete call-site enumerations,
  cross-file references (including to instruction files), a figure nothing pins, and a rule a
  hook, lint or test already enforces: the gate is the record. A pointer within one file is fine.
- **Keep regardless**: framework behaviour a reviewer can't re-derive, a caller contract, and the
  last copy of a fact. A rationale shared by neighbouring declarations is stated once above the
  group. A test's name carries what it tests; a comment may record the bug or edge that is why
  the case exists.
- Plain declarative voice, one to three lines. Describe, don't instruct, except to warn against
  an attractive wrong fix.
- Don't add a comment that wasn't there as part of tidying one that was.
