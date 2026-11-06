---
paths:
  - "**/test/**"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/spec/**"
  - "**/*_test.*"
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/test_*.*"
  - "**/conftest.*"
  - "**/*Tests/**"
  - "**/*Tests.*"
---

# Tests

A test fails when the behaviour is wrong and says which behaviour from its name alone.

- **Every fix gets the test that would have caught it**, written first and seen failing.
- **A published contract gets a pin** (`contracts.md`). A rule gets a test per case worth
  enumerating; presentation code only where it selects.
- **Coverage is a diagnostic, never a target.** Ask which behaviour is unprotected, not which
  line is unvisited.
- **Test at the cheapest level that fails for the right reason.**
- **Real collaborators over mocks**; mock only what is slow, non-deterministic or external.
- **A test owns its clock, randomness, ordering and data.** Control concurrency with a fake
  scheduler or a signal, never a sleep. A flake is a bug in the test: fix the non-determinism or
  delete the test, never retry-on-fail.
- **Run the whole suite before claiming it passes** and report the counts. A fast subset is for
  iteration only.
- **A test red on the base branch too** is pre-existing or flaky, not this diff's. Say which; don't retry until green.
- **Never change a test to make a change pass** without stating in the PR that the behaviour
  changed and why the old expectation was wrong.
