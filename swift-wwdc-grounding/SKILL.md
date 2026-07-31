---
name: swift-wwdc-grounding
description: >
  Answer Swift/Apple-platform questions from Apple's actual WWDC sessions — locate the real
  session, fetch its real transcript and sample code, and quote it with a session citation
  instead of asserting from model memory. Triggers for: "what did Apple actually say about X",
  "what's new in Swift/SwiftUI/SwiftData/Xcode", "is this still the recommended way", "is this
  API current", "which WWDC session covers X", "ground this in Apple's guidance", "cite the
  session", "per WWDC", "did this change in Swift 6.x / iOS 26 / iOS 27", or checking whether a
  pattern in the codebase has been superseded by a newer Apple recommendation. Do NOT trigger
  for ordinary iOS/Swift implementation work with no currency or sourcing question — scaffolding
  a feature, writing a view, adding networking, writing tests (that's `ios-engineering`); for
  #Preview formatting (that's the `swiftui-rules` path-scoped rule); for porting an app between
  web and iOS (`port-web-to-ios`/`port-ios-to-web`); or for non-Apple platforms.
allowed-tools: Task, WebFetch, WebSearch, Read, Edit, Write, Glob, Grep
---

Answer from what Apple actually said on stage, not from what the model remembers Apple saying.
Swift and the Apple SDKs revise their own guidance every June — `@MainActor` defaults,
`Observable` vs `ObservableObject`, Swift Testing vs XCTest, SwiftData migration, strict
concurrency — and model-recalled "best practice" silently ages into last-cycle advice that still
compiles. This skill closes that gap by retrieving the primary source before answering.

## The grounding contract

This is the whole point of the skill; everything else is mechanism.

- **Never assert an Apple API, default, or recommendation from memory while this skill is
  active.** Fetch the session, then answer.
- **Every substantive claim carries a citation** — session title, year, ID, and URL (see
  "Citation format").
- **If retrieval fails, say so in the answer.** Never silently fall back to memory and present
  it in the same voice as a sourced claim. See "When retrieval fails".
- **Recency beats authority.** A 2023 session is Apple's guidance *as of 2023*. Always check
  whether a newer cycle superseded it before quoting it as current.

## Procedure

**1 — Scope the question.** Name the specific Swift/SDK claim to be verified. Vague scope is the
main cause of a useless retrieval: "how should I do concurrency" is not a claim; "is
`@MainActor`-by-default the recommended target setting as of Swift 6.2+" is.

If the question is about existing code, read the relevant source first so the retrieval targets
the actual pattern in use, and note the project's deployment target and Swift version — a
session's advice is only actionable above the OS version that shipped it.

**2 — Locate the session.** Read `references/session-index.md` first — it is a curated
topic→session map covering the Swift-relevant WWDC25 and WWDC26 catalog, and resolves most
lookups without a search. If the topic isn't there, or the index may be stale for it, search
Apple directly:

- `WebSearch` with `allowed_domains: ["developer.apple.com"]` for the topic.
- Or browse a year's catalog at `https://developer.apple.com/videos/wwdc<year>/`, and the topic
  guides at `https://developer.apple.com/wwdc<yy>/guides/<topic>/`.

Session pages live at `https://developer.apple.com/videos/play/wwdc<year>/<id>/`.

Prefer, in order: the newest `What's new in <framework>` session for the current cycle → a
deep-dive session on the specific API → an older foundational session for concepts that haven't
changed. When two cycles disagree, the newer one wins and the change itself is worth reporting.

**3 — Retrieve the primary source.** Fetch the session page — the full transcript and its code
samples are on it. A transcript is long; keep it out of the main conversation by delegating
retrieval to a subagent: read `retriever-agent.md`'s body and pass it as the prompt to the
`Agent` tool (`subagent_type: general-purpose`), appending the specific claim to verify and the
session URL(s). The subagent returns extracted quotes, code, and citations — not the transcript.

Retrieve inline (plain `WebFetch`) only for a single narrow lookup where one targeted question
against one page settles it.

**4 — Extract.** Keep the verbatim quote that supports or refutes the claim, plus any sample
code Apple showed. Note the OS/Swift version the guidance is gated on. If the transcript is
ambiguous or the session only gestures at the API, say that rather than resolving the ambiguity
by inference — an honest "the session doesn't specify" is the correct output.

**5 — Answer, and apply.** Lead with the sourced finding, then the consequence for the user's
code. If the question came with code, apply the change (respecting the project's existing
conventions and deployment target) and cite the session in the response — not in a code comment.

## Citation format

Inline, after the claim:

> `@Observable` supersedes `ObservableObject` for new code — *Discover Observation in SwiftUI*
> (WWDC23, session 10149, https://developer.apple.com/videos/play/wwdc2023/10149/)

For a direct quote, mark it as one and attribute the speaker's framing where it matters
("Doug from the Swift team"), so a paraphrase is never mistaken for Apple's own words.

## When retrieval fails

Network blocked, page unreachable, no session covers the topic, or the transcript doesn't
address the claim. In every case, **name the failure in the answer** and label what follows:

- **No session covers it** — say so. Not everything has a WWDC session; Apple's documentation
  (`developer.apple.com/documentation/…`), the Swift Evolution proposal (`swift.org`), or the
  framework's release notes may be the real primary source, and citing one of those is a valid
  outcome of this skill.
- **Unreachable / offline** — state that grounding was attempted and failed, give the
  best-effort answer explicitly marked as unverified model knowledge, and name the session that
  should be checked when connectivity returns.
- **Transcript doesn't settle it** — report what the session *does* say and what it leaves open.

A clearly-labeled unverified answer is acceptable. An unlabeled one defeats the skill.

## Guardrails

- **Sample code outranks transcript prose.** The spoken transcript compresses and simplifies;
  the on-screen code is the API contract. Where they differ, trust the code and say so.
- **A session is not a compatibility matrix.** Sessions describe the newest OS. Before applying
  anything, check it against the project's actual deployment target — and never raise that
  target to make a session's advice apply without flagging it.
- **Don't over-retrieve.** One or two sessions answer most questions. Fetching six transcripts
  to answer a narrow question is the failure mode this skill's subagent delegation exists to
  avoid.
- **Transcripts are auto-generated.** Expect API names to be mangled phonetically
  ("at main actor", "Swift UI"). Normalize silently; never quote a mangling as an API name.
- **Stay in the grounding lane.** This skill verifies and cites. Broad implementation work —
  scaffolding, architecture choice, test infrastructure — is `ios-engineering`'s job; hand off
  once the sourced finding is established rather than absorbing the whole build task.
- **Record the decision if it's load-bearing.** If a finding changes an architectural choice,
  use `write-adr` to record it, with the session as the cited evidence.

## Why this is a separate skill from `ios-engineering`

`ios-engineering` is the broad build-an-iOS-app skill; its references are distilled prose that
encodes what good Swift looks like. That distillation is exactly what can't be trusted for a
currency question — it has no provenance and no expiry. This skill exists to supply provenance
on demand, which is why its trigger phrases are all about *sourcing and currency* rather than
about Swift work in general. The two are meant to compose: `ios-engineering` builds,
`swift-wwdc-grounding` verifies the version-sensitive premises it builds on.

The bundled `references/session-index.md` is a fast path, not the source of truth — the
transcript is. The index is allowed to go stale each June without making an answer wrong,
because a stale index costs one extra search and never substitutes for retrieval.
