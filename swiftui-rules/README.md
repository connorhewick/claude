# swiftui-rules

**Type:** rule · installs to `~/.claude/rules/swiftui-rules.md`

SwiftUI `#Preview` conventions: always include a working `#Preview` for every `View`, keep
`ENABLE_PREVIEWS` on. Scoped with `paths: ["**/*.swift"]` frontmatter, so it only enters context
in sessions that actually touch Swift files — it stays inert (no context cost) in every other
project, rather than loading unconditionally the way `global-rules` or a concern-scoped rule
like [`git-rules`](../git-rules) does.

Split out of [`global-rules`](../global-rules), which had this content duplicated across two
sections (`## SwiftUI` and `## SwiftUI previews`).
