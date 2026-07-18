# global-rules

**Type:** global-rules · installs to `~/.claude/CLAUDE.md`

Personal, cross-project defaults — installed at `~/.claude/CLAUDE.md` so they load in every
project on this machine, not just this repo.

The only component that installs to a single well-known file directly under `~/.claude/`
instead of a per-component subdirectory (`skills/`, `agents/`, `rules/`, …). Any existing
`~/.claude/CLAUDE.md` is backed up to a timestamped `.bak` before being overwritten, so personal
additions made below the marked line are always recoverable.
