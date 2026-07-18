#!/usr/bin/env bash
# Shared helpers for install.sh / uninstall.sh. Sourced by both — one copy of
# path resolution and per-type install/remove logic, not duplicated per
# component.

# Repo root (the directory containing this repo's component directories).
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Destination: ~/.claude, or $CLAUDE_CONFIG_DIR if set (lets tests/dry-runs
# point this at a scratch directory instead of the real home config).
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Back up a file/dir before it's overwritten or removed, if it pre-exists and
# isn't already what we'd install (idempotent no-op when unchanged).
backup_if_exists() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  local backup="$target.bak.$(date +%Y%m%d%H%M%S)"
  cp -r "$target" "$backup"
  echo "  backed up existing $target -> $backup"
}

# --- skill: <name>/SKILL.md (+ optional scripts/) -> ~/.claude/skills/<name>/
install_skill() {
  local name="$1"
  local dest="$CLAUDE_DIR/skills/$name"
  local staging
  staging="$(mktemp -d)"
  cp -r "$SRC/$name/." "$staging/"
  rm -f "$staging/README.md"

  if [[ -d "$dest" ]] && diff -rq "$staging" "$dest" >/dev/null 2>&1; then
    echo "skill $name is already up to date — nothing to do."
    rm -rf "$staging"
    return 0
  fi

  mkdir -p "$CLAUDE_DIR/skills"
  backup_if_exists "$dest"
  rm -rf "$dest"
  mv "$staging" "$dest"
  echo "installed skill: $name -> $dest"
}

uninstall_skill() {
  local name="$1"
  rm -rf "$CLAUDE_DIR/skills/$name"
  echo "removed skill: $name"
}

# --- agent: <name>/agent.md -> ~/.claude/agents/<name>.md
install_agent() {
  local name="$1"
  local dest="$CLAUDE_DIR/agents/$name.md"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/agent.md" "$dest"; then
    echo "agent $name is already up to date — nothing to do."
    return 0
  fi
  mkdir -p "$CLAUDE_DIR/agents"
  backup_if_exists "$dest"
  cp "$SRC/$name/agent.md" "$dest"
  echo "installed agent: $name -> $dest"
}

uninstall_agent() {
  local name="$1"
  rm -f "$CLAUDE_DIR/agents/$name.md"
  echo "removed agent: $name"
}

# --- rule: <name>/rule.md -> ~/.claude/rules/<name>.md
install_rule() {
  local name="$1"
  local dest="$CLAUDE_DIR/rules/$name.md"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/rule.md" "$dest"; then
    echo "rule $name is already up to date — nothing to do."
    return 0
  fi
  mkdir -p "$CLAUDE_DIR/rules"
  backup_if_exists "$dest"
  cp "$SRC/$name/rule.md" "$dest"
  echo "installed rule: $name -> $dest"
}

uninstall_rule() {
  local name="$1"
  rm -f "$CLAUDE_DIR/rules/$name.md"
  echo "removed rule: $name"
}

# --- output style: <name>/output-style.md -> ~/.claude/output-styles/<name>.md
# Installing a style doesn't select it — the user still opts in via
# `/config` (or the `outputStyle` setting) themselves.
install_output_style() {
  local name="$1"
  local dest="$CLAUDE_DIR/output-styles/$name.md"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/output-style.md" "$dest"; then
    echo "output style $name is already up to date — nothing to do."
    return 0
  fi
  mkdir -p "$CLAUDE_DIR/output-styles"
  backup_if_exists "$dest"
  cp "$SRC/$name/output-style.md" "$dest"
  echo "installed output style: $name -> $dest"
}

uninstall_output_style() {
  local name="$1"
  rm -f "$CLAUDE_DIR/output-styles/$name.md"
  echo "removed output style: $name"
}

# --- slash command: <name>/command.md -> ~/.claude/commands/<name>.md
# No component uses this type yet; kept ready for the first one. Named
# install_command_file (not install_command) so a component ever literally
# named "command" wouldn't collide with its own wrapper function, mirroring
# the install_statusline_file naming below.
install_command_file() {
  local name="$1"
  local dest="$CLAUDE_DIR/commands/$name.md"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/command.md" "$dest"; then
    echo "command $name is already up to date — nothing to do."
    return 0
  fi
  mkdir -p "$CLAUDE_DIR/commands"
  backup_if_exists "$dest"
  cp "$SRC/$name/command.md" "$dest"
  echo "installed command: $name -> $dest"
}

uninstall_command_file() {
  local name="$1"
  rm -f "$CLAUDE_DIR/commands/$name.md"
  echo "removed command: $name"
}

# --- hook: <name>/hook.sh + <name>/hook.json -> ~/.claude/hooks/<name>.sh
# plus a jq-merged matcher-group entry under settings.json's .hooks.<event>.
# hook.json supplies the event (required, e.g. "PostToolUse") and matcher
# (optional, defaults to "*"); the installed script's path becomes the
# handler's "command" (type "command" only — this repo has no use yet for
# the http/mcp_tool/prompt hook types). Uninstall only removes handler
# entries whose command points at this component's script, so it never
# touches hooks the user configured by hand or that another component owns.
install_hook() {
  local name="$1"
  local dest="$CLAUDE_DIR/hooks/$name.sh"
  local meta="$SRC/$name/hook.json"
  local event matcher
  event="$(jq -r '.event' "$meta")"
  matcher="$(jq -r '.matcher // "*"' "$meta")"

  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/hook.sh" "$dest"; then
    echo "hook $name script is already up to date."
  else
    mkdir -p "$CLAUDE_DIR/hooks"
    backup_if_exists "$dest"
    cp "$SRC/$name/hook.sh" "$dest"
    chmod +x "$dest"
    echo "installed hook script: $name -> $dest"
  fi

  local settings="$CLAUDE_DIR/settings.json"
  mkdir -p "$CLAUDE_DIR"
  [[ -f "$settings" ]] || echo '{}' > "$settings"

  if jq -e --arg event "$event" --arg matcher "$matcher" --arg cmd "$dest" '
      [(.hooks[$event] // [])[] | select(.matcher == $matcher) | (.hooks // [])[] | select(.command == $cmd)]
      | length > 0
    ' "$settings" >/dev/null; then
    echo "  settings.json already has this hook registered under $event"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  jq --arg event "$event" --arg matcher "$matcher" --arg cmd "$dest" '
    .hooks = (.hooks // {}) |
    .hooks[$event] = (.hooks[$event] // []) |
    if ([.hooks[$event][] | select(.matcher == $matcher)] | length) > 0 then
      .hooks[$event] = [
        .hooks[$event][]
        | if .matcher == $matcher
          then .hooks = ((.hooks // []) + [{"type": "command", "command": $cmd}])
          else . end
      ]
    else
      .hooks[$event] += [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd}]}]
    end
  ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  echo "  settings.json .hooks.$event -> $dest (matcher: $matcher)"
}

uninstall_hook() {
  local name="$1"
  local dest="$CLAUDE_DIR/hooks/$name.sh"
  local meta="$SRC/$name/hook.json"
  local event
  event="$(jq -r '.event' "$meta")"

  local settings="$CLAUDE_DIR/settings.json"
  if [[ -f "$settings" ]]; then
    local tmp
    tmp="$(mktemp)"
    jq --arg event "$event" --arg cmd "$dest" '
      .hooks = (.hooks // {}) |
      .hooks[$event] = [
        (.hooks[$event] // [])[]
        | .hooks = [(.hooks // [])[] | select(.command != $cmd)]
        | select((.hooks | length) > 0)
      ] |
      if (.hooks[$event] | length) == 0 then .hooks |= del(.[$event]) else . end
    ' "$settings" > "$tmp"
    mv "$tmp" "$settings"
    echo "  removed $name's entries from settings.json .hooks.$event"
  fi

  rm -f "$dest"
  echo "removed hook: $name"
}

# --- statusline: <name>/statusline.sh -> ~/.claude/statuslines/<name>.sh
# plus a jq patch setting ~/.claude/settings.json's .statusLine. Uninstall
# only clears .statusLine if it still points at this component, so it never
# clobbers a statusline the user later set by hand.
#
# Named install_statusline_file/uninstall_statusline_file (not
# install_statusline/uninstall_statusline) to avoid colliding with the
# per-component install_statusline()/uninstall_statusline() wrapper functions
# in install.sh/uninstall.sh for the component actually named "statusline".
install_statusline_file() {
  local name="$1"
  local dest="$CLAUDE_DIR/statuslines/$name.sh"
  mkdir -p "$CLAUDE_DIR/statuslines"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/statusline.sh" "$dest"; then
    echo "statusline $name is already up to date — nothing to do."
  else
    backup_if_exists "$dest"
    cp "$SRC/$name/statusline.sh" "$dest"
    chmod +x "$dest"
    echo "installed statusline: $name -> $dest"
  fi

  local settings="$CLAUDE_DIR/settings.json"
  mkdir -p "$CLAUDE_DIR"
  [[ -f "$settings" ]] || echo '{}' > "$settings"
  local tmp
  tmp="$(mktemp)"
  jq --arg cmd "$dest" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  echo "  settings.json .statusLine -> $dest"
}

# --- global-rules: <name>/CLAUDE.md -> ~/.claude/CLAUDE.md
# The one component that installs to a single well-known file directly under
# $CLAUDE_DIR rather than a per-component subdirectory.
install_claude_md_file() {
  local name="$1"
  local dest="$CLAUDE_DIR/CLAUDE.md"
  if [[ -f "$dest" ]] && cmp -s "$SRC/$name/CLAUDE.md" "$dest"; then
    echo "$name is already up to date — nothing to do."
    return 0
  fi
  mkdir -p "$CLAUDE_DIR"
  backup_if_exists "$dest"
  cp "$SRC/$name/CLAUDE.md" "$dest"
  echo "installed $name -> $dest"
}

uninstall_claude_md_file() {
  local name="$1"
  rm -f "$CLAUDE_DIR/CLAUDE.md"
  echo "removed $name"
}

uninstall_statusline_file() {
  local name="$1"
  local dest="$CLAUDE_DIR/statuslines/$name.sh"
  local settings="$CLAUDE_DIR/settings.json"

  if [[ -f "$settings" ]] && [[ "$(jq -r '.statusLine.command // empty' "$settings")" == "$dest" ]]; then
    local tmp
    tmp="$(mktemp)"
    jq 'del(.statusLine)' "$settings" > "$tmp"
    mv "$tmp" "$settings"
    echo "  cleared .statusLine from $settings"
  else
    echo "  .statusLine no longer points at $dest — leaving settings.json alone"
  fi

  rm -f "$dest"
  echo "removed statusline: $name"
}
