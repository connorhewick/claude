# split-commits

**Type:** skill · installs to `~/.claude/skills/split-commits/`

Breaks an uncommitted working tree that spans multiple concerns into one atomic Conventional
Commit per concern — path-level grouping by default, hunk-level splitting (via a zero-context
patch) when one file mixes concerns. Proposes the commit plan and waits for explicit approval
before staging or committing anything; never pushes.

Auto-invoked for requests like "commit these changes" or "split this into commits", or run
explicitly with `/split-commits`.
