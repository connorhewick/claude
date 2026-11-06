# Working on claude-config

This repo is the source of a Claude Code config bundle. A session here edits the bundle; it is
governed by whatever `~/.claude/` holds, which is what `install.sh` last copied — not this tree.
`README.md` owns the layout and the ownership table: read the table before adding a fact.

## Where things install

- `claude-rules/global-rules.md` becomes `~/.claude/CLAUDE.md`. It is not a rule: `install.sh`
  skips it when copying `claude-rules/`, and it carries no frontmatter.
- Every other `claude-rules/*.md` goes to `~/.claude/rules/`; each `claude-skills/<name>/`
  replaces `~/.claude/skills/<name>/`.
- This file installs nowhere.

## Changing the bundle

- **Run `./check.sh` after every edit.** It fails on a reference to a missing file, section or
  skill; and on frontmatter that would make a rule always-on. `install.sh` won't install a tree
  that fails it.
- **Refer to a section by its heading**, as `` `ship` §Write the body ``, never by number. A
  number keeps resolving after a reorder, to the wrong section; `check.sh` rejects it.
- **Adding a rule**: `rules-authoring.md` loads when a file in `claude-rules/` is read, and
  decides whether it is a new file or a section in an existing one.
- **Adding a fact another file already states**: don't. Add a pointer.
- **A skill's `allowed-tools` is a permission grant, not a sandbox**: it pre-approves those
  tools for the invoking turn so they don't prompt, and every other tool stays callable
  regardless. Write it as the set the skill's own steps need, never as a fence — `Bash(*)` in a
  read-only skill grants unprompted shell access rather than restricting it. `disallowed-tools`
  is the field that actually removes a tool.
- **Naming a slash command**: `install.sh` lists every one the bundle names. A rule that names a
  command the CLI doesn't have fails at the moment it is needed — delete the line rather than
  leave it.
- **A change reaches sessions only after `./install.sh` and a new session.** Confirm with
  `/context` there; this session keeps what it loaded at start.
- Without an `origin` remote, branch from local `main`; the fetch in `session-hygiene.md` and
  `ship`'s push and PR steps have nothing to talk to.
