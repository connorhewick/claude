# Swift Codable Type Designer

Design Codable types for production iOS apps that fail loudly during development, degrade
gracefully in production, and keep the API's shape from leaking into the rest of the app.

## Overview

Codable is Swift's contract layer with the outside world. A well-designed Codable layer turns
malformed server data into one diagnosable error at the boundary instead of `nil` surprises
deep in business logic, and lets the backend rename a field without touching forty view files.
The core philosophy: **DTOs mirror the wire format exactly; domain models mirror what the app
needs; an explicit mapping connects them.** Resist the temptation to make one type serve both —
that is the single most common source of pain in iOS networking code.

## Core Concepts

### DTOs are not domain models

A DTO (`UserDTO`) exists to match JSON: snake-cased origins, optional everything the server
might omit, stringly-typed enums. A domain model (`User`) exists to make invalid states
unrepresentable: non-optional fields the app requires, real `URL`/`Date`/enum types. The
mapping function between them is where you apply defaults, reject garbage, and decouple the API
version from the UI. When the type is trivial and stable, collapsing the two is acceptable —
but make that an explicit decision, not a default.

### Synthesized conformance is the goal, not a compromise

The compiler-generated `Codable` is correct, fast, and updates itself when you add properties.
Every hand-written `init(from:)` is code that can drift from the type's stored properties.
Escalate only when forced: synthesized → synthesized + `CodingKeys` (renames, skipped fields) →
custom `init(from:)` (structural transformation). Never write a custom initializer just to
rename keys.

### Decoding failures are data, not exceptions to swallow

`DecodingError` tells you the exact key path and expectation that failed — that context is
gold in production logs. Catch it at the network layer, log `context.codingPath`, and surface a
typed app error. A bare `try?` at the decode site converts a precise diagnosis into "the screen
is blank and nobody knows why."

### One bad element should not sink the array

Servers ship heterogeneous lists, and one malformed item in `results[847]` will fail the entire
synthesized decode of the array. Decide per-collection: is partial data acceptable? If yes, use
a lossy decoding wrapper that drops bad elements (and logs them); if the list is, say, line
items of an invoice, fail the whole decode — partial financial data is worse than none.

### Dates and raw data are strategies, not string fields

`Date` and `Data` cross the wire as strings/numbers; the decoder's `dateDecodingStrategy` /
`dataDecodingStrategy` centralize the conversion. Storing `createdAt: String` in a model is an
abdication — every consumer now re-parses it. One caveat: `.iso8601` does **not** parse
fractional seconds; if the backend sends `2024-01-01T12:00:00.123Z`, you need a custom strategy
or it fails at runtime, not compile time.

### Polymorphic JSON needs a discriminator

When `{"type": "image", ...}` and `{"type": "video", ...}` share an endpoint, decode the
discriminator first, then dispatch to the concrete payload type — Swift's analogue of a tagged
union. Trying each candidate type in turn ("if it decodes as X...") is slow, order-dependent,
and produces useless error messages.

## Decision Framework

| Situation | Approach |
|---|---|
| JSON keys match property names (or differ only by snake_case, uniformly) | Synthesized Codable; set `keyDecodingStrategy = .convertFromSnakeCase` once on the shared decoder |
| A few keys renamed, fields skipped, or mixed naming conventions | Synthesized + explicit `CodingKeys` enum (and drop `convertFromSnakeCase` for that decoder — never combine both) |
| Flattening nested JSON, value transformation, version tolerance | Custom `init(from:)` with `nestedContainer` |
| Heterogeneous array with a `type` field | Discriminated enum: decode the tag, switch, decode payload |
| Server may omit a field vs. field may be `null` vs. field is garbage | `decodeIfPresent` for the first two; lossy wrapper only when garbage is expected and tolerable |
| List where partial results are useful (feeds, search) | `LossyArray` wrapper — drop bad elements, log them |
| List where every element matters (order items, permissions) | Plain array — fail the whole decode |
| Type is also used by the UI and stored locally | Split: DTO + domain model + `toDomain()` mapping |
| Throwaway internal tool, stable schema | One Codable type is fine — say so in a comment |

Encoding side: if the type is only ever decoded, conform to `Decodable` alone — a smaller
contract documents intent and avoids writing untested `encode(to:)` paths.

## Workflow

1. **Read the existing code and a real response.** Find the project's networking layer, shared
   `JSONDecoder` configuration, and existing DTO conventions (see `ios-networking.md`). Get an actual JSON sample (curl,
   API docs, proxy capture) — never design from a verbal description of the payload.
2. **Inventory the payload**: which fields are always present, nullable, sometimes absent,
   polymorphic. When the docs and the sample disagree, trust the sample and flag the
   discrepancy.
3. **Decide DTO vs. combined model** using the framework above; name DTOs with a suffix
   (`UserDTO`/`UserResponse`) so the boundary is greppable.
4. **Write the types at the lowest escalation level** that works: synthesized first, CodingKeys
   only where names differ, custom `init(from:)` only for structure changes.
5. **Configure the decoder once** (date strategy, key strategy) in the network layer — not per
   call site.
6. **Write the domain mapping**, applying defaults and rejecting invalid combinations there,
   not in views.
7. **Add a round-trip/fixture test**: decode a checked-in real JSON fixture; for Encodable
   types, encode → decode → compare with `Equatable`.
8. **Verify against the Quality Checklist** below, including the malformed-input cases (missing
   key, null, wrong type, unknown enum case).

## Patterns

### DTO + domain mapping (the default architecture)

```swift
struct UserDTO: Decodable {
    let id: Int
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct User: Equatable, Hashable, Identifiable {
    let id: Int
    let displayName: String
    let avatarURL: URL?
}

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            displayName: displayName?.nilIfBlank ?? "Anonymous",
            avatarURL: avatarUrl.flatMap(URL.init(string:))
        )
    }
}
```

Defaults and URL parsing live in `toDomain()` — the DTO stays a faithful mirror of the wire.

### Shared decoder configuration (dates with fractional seconds)

```swift
extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let withFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            if let date = try? withFractionalSeconds.parse(string) { return date }
            if let date = try? Date.ISO8601FormatStyle().parse(string) { return date }  // server omits millis sometimes
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date: \(string)"))
        }
        return decoder
    }()
}
```

Prefer `Date.ISO8601FormatStyle` over `ISO8601DateFormatter` in new code: it's a `Sendable` value type with no mutable `formatOptions` to race on, versus the older NSObject-based formatter.

### Custom init(from:) to flatten nesting

```swift
struct Article: Decodable {
    let id: Int
    let title: String
    let authorName: String   // wire: { "author": { "name": ... } }

    enum CodingKeys: String, CodingKey { case id, title, author }
    enum AuthorKeys: String, CodingKey { case name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        let author = try c.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author)
        authorName = try author.decode(String.self, forKey: .name)
    }
}
```

### Polymorphic JSON via discriminated enum

```swift
enum FeedItem: Decodable {
    case post(Post)
    case ad(Ad)
    case unknown(type: String)   // forward compatibility: new server types don't break old clients

    enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self)
            .decode(String.self, forKey: .type)
        switch type {
        case "post": self = .post(try Post(from: decoder))
        case "ad":   self = .ad(try Ad(from: decoder))
        default:     self = .unknown(type: type)
        }
    }
}
```

The `.unknown` case is a deliberate contract decision: render nothing for new types instead of
failing the whole feed. For closed sets (payment states), throw instead — silently ignoring an
unknown payment status is a bug factory.

### Lossy array for tolerant lists

```swift
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            do { elements.append(try container.decode(Element.self)) }
            catch {
                _ = try? container.decode(AnyDecodable.self)  // consume the bad element
                assertionFailure("Dropped element: \(error)") // loud in debug, silent in release
            }
        }
        self.elements = elements
    }
}

private struct AnyDecodable: Decodable {}
```

### Unknown-tolerant string enums

```swift
enum Status: String, Decodable {
    case active, suspended, deleted, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Status(rawValue: raw) ?? .unknown
    }
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| `keyNotFound` for a key that "is right there" | `convertFromSnakeCase` combined with explicit `CodingKeys` — the strategy transforms keys *before* matching, so your snake_case raw values no longer match | Pick one mechanism per decoder; with custom CodingKeys, use the default key strategy |
| Blank screens, no errors anywhere | `try? decoder.decode(...)` swallowing `DecodingError` | Catch, log `error` (codingPath + description), surface a typed failure |
| Whole feed fails because one item is malformed | Synthesized array decoding is all-or-nothing | `LossyArray` where partial data is acceptable; keep strict where it isn't |
| Dates parse in dev, fail in prod | `.iso8601` strategy vs. fractional seconds, or per-call formatter mismatches | One shared decoder with a custom strategy handling both forms (pattern above) |
| Every property is optional "to be safe" | Fear of decode failures pushed into the type system | Only fields the API actually omits/nulls are optional in the DTO; the domain model resolves them to real values |
| Adding a property silently stops it being decoded | Hand-written `init(from:)` not updated alongside stored properties | Prefer synthesis; if custom init is required, a fixture test catches the drift |
| App update breaks on a new server enum value | Closed `String` enum decode throws on unknown raw value | Add an `.unknown` case for open sets; document closed sets as intentionally strict |
| Subclass properties come back nil/default | Codable synthesis does not compose across class inheritance | Use structs + composition; if classes are forced, implement both `init(from:)` and `encode(to:)` calling `super` with `superDecoder()` |
| API rename forces edits across the app | Wire type used directly by views and persistence | Introduce the DTO/domain split; views depend only on the domain model |

## Quality Checklist

- [ ] No `try?` around `decode` calls — every `DecodingError` is logged with its coding path and surfaced as a typed error
- [ ] DTOs and domain models are separate for any type touched by UI or persistence (or the decision to combine is commented)
- [ ] Decoder configuration (date/key strategy) lives in exactly one shared place
- [ ] `convertFromSnakeCase` and explicit `CodingKeys` are never mixed on the same decoder
- [ ] Date handling tolerates the backend's actual formats, including fractional seconds, with a test proving it
- [ ] Optionality in DTOs mirrors the real API (verified against a sample), not defensive guessing
- [ ] Collections decide explicitly: lossy (with debug logging) vs. all-or-nothing
- [ ] Polymorphic payloads decode the discriminator first; open sets have an `.unknown` case, closed sets deliberately throw
- [ ] Custom `init(from:)` exists only where synthesis cannot express the mapping
- [ ] Types conform to `Decodable` only, unless encoding is genuinely needed (then a round-trip test exists)
- [ ] A real JSON fixture is checked in and decoded in a unit test, including a malformed variant
- [ ] Domain models conform to `Equatable`/`Hashable`/`Identifiable` as their usage (diffing, sets, SwiftUI lists) requires
