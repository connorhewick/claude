#!/usr/bin/env bash
# Enables this repo's tracked git hooks by pointing core.hooksPath at .githooks/.
# Idempotent and safe: refuses to clobber an existing custom hooksPath (husky,
# etc.) so it never silently disables another tool's hooks.
#
# Run once after cloning:  scripts/install-hooks.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "install-hooks: not a git repository — nothing to do." >&2
  exit 0
fi

current="$(git config --get core.hooksPath || true)"
if [[ -n "$current" && "$current" != ".githooks" ]]; then
  echo "install-hooks: core.hooksPath is already set to '$current' (husky/custom?)." >&2
  echo "  Left as-is. To enable the pre-push doc-sync gate, chain .githooks/pre-push in manually." >&2
  exit 0
fi

chmod +x .githooks/* 2>/dev/null || true
git config core.hooksPath .githooks
echo "install-hooks: core.hooksPath → .githooks (pre-push doc-sync gate active)."
