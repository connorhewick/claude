#!/usr/bin/env bash
# gather_context.sh — Collect session context for handoff document generation.
#
# Usage: bash gather_context.sh [project_root] [hours_lookback]
#   project_root   — path to scan (default: current directory)
#   hours_lookback — how far back to look for modified files (default: 8)
#
# Output: structured text sections to stdout, suitable for parsing.
# Exit codes: 0 = success, 1 = error

set -euo pipefail

PROJECT_ROOT="${1:-.}"
HOURS="${2:-8}"

cd "$PROJECT_ROOT" || { echo "ERROR: Cannot access $PROJECT_ROOT"; exit 1; }

echo "=== SESSION CONTEXT REPORT ==="
echo "Generated: $(date -Iseconds)"
echo "Project root: $(pwd)"
echo ""

# --- Git state ---
echo "=== GIT STATE ==="
if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Branch: $(git branch --show-current 2>/dev/null || echo 'detached HEAD')"
    echo ""
    echo "--- Status ---"
    git status --short 2>/dev/null || echo "(no changes)"
    echo ""
    echo "--- Diff stat ---"
    git diff --stat 2>/dev/null || echo "(no unstaged changes)"
    echo ""
    echo "--- Staged diff stat ---"
    git diff --cached --stat 2>/dev/null || echo "(nothing staged)"
    echo ""
    echo "--- Recent commits (last 20) ---"
    git log --oneline -20 2>/dev/null || echo "(no commits)"
    echo ""
    echo "--- Stash list ---"
    git stash list 2>/dev/null || echo "(no stashes)"
else
    echo "Not a git repository."
fi
echo ""

# --- Recently modified files ---
echo "=== RECENTLY MODIFIED FILES (last ${HOURS}h) ==="
# Use -mmin for portability; hours * 60 = minutes
MINUTES=$((HOURS * 60))
find . -maxdepth 5 \
    \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
       -o -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.toml' \
       -o -name '*.json' -o -name '*.sql' -o -name '*.go' -o -name '*.rs' \) \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/venv/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -mmin "-${MINUTES}" \
    -print0 2>/dev/null | xargs -0 ls -lt 2>/dev/null | head -30 || echo "(no recent files found)"
echo ""

# --- Project structure overview ---
echo "=== PROJECT STRUCTURE (depth 3) ==="
find . -maxdepth 3 -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
       -o -name '*.go' -o -name '*.rs' \) \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/venv/*' \
    -not -path '*/__pycache__/*' \
    2>/dev/null | sort | head -60 || echo "(no source files found)"
echo ""

echo "=== END CONTEXT REPORT ==="
