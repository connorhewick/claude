---
paths:
  - "dist/**"
  - "build/**"
  - "out/**"
  - "vendor/**"
  - "generated/**"
  - "**/*.generated.*"
---

# Generated / vendored paths are read-only

Files under these paths are produced by tooling, not hand-written. Never edit them directly —
changes are silently overwritten by the next build/install, and hand-edits mask real problems
in the generation step instead of fixing them.

If a file here needs to change, fix the source it's generated from (or the vendoring/install
step), then regenerate.

**Customize the `paths` glob list above per project.** This harness has no stack, so the
globs above are a generic starting template (common build-output, vendoring, and
codegen conventions), not an exhaustive or authoritative list. Add or remove patterns to match
what a given project actually generates or vendors.
