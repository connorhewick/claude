---
paths:
  - "dist/**"
  - "build/**"
  - "out/**"
  - "vendor/**"
  - "generated/**"
  - "**/*.generated.*"
  - "plugin/**"
---

# Generated / vendored paths are read-only

Files under these paths are produced by tooling, not hand-written. Never edit them directly —
changes are silently overwritten by the next build/install, and hand-edits mask real problems
in the generation step instead of fixing them.

If a file here needs to change, fix the source it's generated from (or the vendoring/install
step), then regenerate.

**Customize the `paths` glob list above per project.** Most of the globs above are a generic
starting template (common build-output, vendoring, and codegen conventions) — add or remove
patterns to match what a given project actually generates or vendors. `plugin/**` is specific
to *this* repo: it's this harness's own generated plugin bundle (`scripts/build-plugin.sh`),
not a generic pattern — drop it if you fork this template for a project that has no such
directory.
