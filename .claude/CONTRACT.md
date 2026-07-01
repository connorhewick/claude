# Verification Contract

This is the language-agnostic seam of the harness. The core never contains stack logic —
every stage's meaning and required output is defined here so a future adapter author can
implement one without reading `.claude/verify`'s source.

## Entrypoint

```
.claude/verify [stage] [--json]
```

- `stage` — optional. One of the declared stages below, or `all` (default).
- `--json` — optional. Emit machine-readable output instead of human-readable text.

## Declared stages

| Stage | Meaning |
|---|---|
| `format` | Source formatting matches the project's formatting rules. |
| `lint` | Static analysis / linting passes. |
| `typecheck` | Type checking passes (adapters for untyped languages may report `pass` unconditionally, or the stage may be omitted from `all` by that adapter's discretion — see "Stages with no meaning for a stack" below). |
| `test` | The automated test suite passes. |
| `build` | The project builds/compiles successfully. |
| `security` | Security scanning (SAST, dependency audit, secret scanning, etc.) passes. |

This list is fixed for this build. Adding a new stage name is a core-repo change (out of scope
for a stack adapter) and must go through the harness maintainers, not an individual adapter.

## Adapter registration

An adapter is a single executable file dropped into `.claude/verify.d/`, named **exactly** after
the stage it implements:

```
.claude/verify.d/format
.claude/verify.d/lint
.claude/verify.d/typecheck
.claude/verify.d/test
.claude/verify.d/build
.claude/verify.d/security
```

- The file must be executable (`chmod +x`).
- Registration is automatic: `.claude/verify` discovers adapters by filename at run time. No
  central registry file to edit.
- At most one adapter per stage. A stack that needs to run multiple tools for one stage (e.g.
  two linters) composes them inside that single adapter script.
- An adapter is invoked with the harness root as its current working directory, no arguments,
  and no assumptions about environment beyond what a normal shell provides.

## Exit-code semantics

**Adapter scripts:**
- Exit `0` → stage passed.
- Exit non-zero → stage failed. Print the reason to stdout/stderr; `verify` surfaces it.

**`.claude/verify` itself:**
- Exit `0` → every requested stage passed.
- Exit non-zero → at least one requested stage failed, OR at least one requested stage has no
  adapter registered (fail-closed — see below).

There is no "warn and pass" outcome. A missing adapter is a failure, not a skip. This is what
makes the Stop-gate (Phase 5) meaningfully block "done" until real adapters exist.

## `--json` output

```json
[
  { "stage": "format",    "status": "absent" },
  { "stage": "lint",      "status": "pass"   },
  { "stage": "typecheck", "status": "absent" },
  { "stage": "test",      "status": "fail"   },
  { "stage": "build",     "status": "absent" },
  { "stage": "security",  "status": "absent" }
]
```

`status` is one of:
- `pass` — adapter ran, exited `0`.
- `fail` — adapter ran, exited non-zero.
- `absent` — no adapter registered for this stage.

## Stages with no meaning for a stack

If a stack genuinely has no concept of a declared stage (e.g. an untyped language and
`typecheck`), the adapter author has two options:
1. Register a trivial adapter for that stage that always exits `0` (documenting why in a
   comment in the adapter script), or
2. Leave the stage unregistered and have the project's own tooling/CI decide not to request
   that specific stage (`.claude/verify typecheck` would still fail-closed; `.claude/verify
   lint test build` — an explicit subset — would simply not ask for it).

The contract does not special-case this; it is an adapter-author decision, made explicit either
way, never silent.

## Worked example: a hypothetical adapter (pseudo-code, not a real language)

This illustrates the *shape* a future adapter takes. It is not tied to any real toolchain.

```
#!/usr/bin/env <shell-or-runtime>
# .claude/verify.d/test — hypothetical adapter, illustrative only
set -euo pipefail

# 1. Locate the stack's test runner however that stack conventionally does so
#    (e.g. a manifest file lookup, a lockfile check, a fixed command).
runner = detect_test_runner()

# 2. Run it, letting its native exit code propagate.
run(runner, "run-tests", "--ci-mode")

# 3. Exit 0 only if the runner reported success; otherwise exit non-zero.
#    Do not swallow the runner's failure and exit 0 — that would defeat fail-closed.
```

Key properties every real adapter must preserve:
- No dependency on anything outside `.claude/verify.d/<stage>` and the stack's own tooling.
- Exit code is the sole signal `verify` trusts; stdout/stderr is for humans (and for `--json`
  mode, only the aggregate stage/status pairs are structured — adapter output itself stays
  free-form text).
- Idempotent and side-effect-free beyond what the stage name implies (e.g. `format` may be
  read-only check-mode rather than a mutating auto-format, at the adapter author's discretion —
  document the choice in the adapter).

## Consumers of this contract

`.claude/hooks/verify-gate.sh` runs on the `Stop` event and calls `.claude/verify --json`,
surfacing the result as feedback. Its own mode switch (`HARNESS_VERIFY_STOP_MODE` in
`.claude/settings.json`'s `env` block — `advise` default | `block`) is independent of the
verify contract itself:
- `advise` — a non-passing result (including every stage `absent`, as in this build) is
  reported to the user/agent, but the session is still allowed to stop.
- `block` — a non-passing result denies stopping (`Stop` hook returns `decision: block`).

With `verify.d/` empty, this build runs in `advise` mode by design: a `block` Stop-gate would
permanently prevent any session from finishing until a real adapter exists, which is correct
once a stack is chosen but not useful before then. Flip `HARNESS_VERIFY_STOP_MODE` to `block`
once the first adapter registers, if you want "done" to be hard-gated by verification.

## Non-goals

- `verify` does not detect language or stack. It has zero knowledge of what an adapter does
  internally.
- `verify` does not install dependencies, provision environments, or manage tool versions —
  that is entirely the adapter's responsibility.
- `verify` does not retry, cache, or parallelize stages. It runs each requested stage's adapter
  once, in the order requested (or the table order for `all`).
