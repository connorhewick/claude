#!/bin/bash
# Claude Code statusline script. Installs to
# ~/.claude/statuslines/statusline.sh (+ patches ~/.claude/settings.json's
# .statusLine).
#
# Reads the session JSON Claude Code pipes in on stdin, parses with jq, and
# outputs a single pipe-delimited (" | ") status line, ANSI colors always on:
# current folder, git branch (* if dirty, up/down arrows if ahead/behind
# upstream), model name (colored by model), effort level, permission mode, a
# 10-block context-usage bar (colored by thresholds), tokens used, cache-hit
# %, session cost, and the 5-hour rate-limit usage with reset time.
#
# Install clears any previous .statusLine this component set; it never
# touches a statusline configured some other way, and uninstalling only
# clears .statusLine if it still points here (see install_statusline_file /
# uninstall_statusline_file in ../common.sh).

export GIT_OPTIONAL_LOCKS=0

input="$(cat)"

get() {
  printf '%s' "$input" | jq -r "$1" 2>/dev/null
}

is_empty() {
  [ -z "$1" ] || [ "$1" = "null" ]
}

segments=()

# ---------------------------------------------------------------------------
# 1. Folder - basename of cwd
# ---------------------------------------------------------------------------
cwd="$(get '.cwd // .workspace.current_dir // empty')"
if ! is_empty "$cwd"; then
  folder="$(basename "$cwd")"
  segments+=("$folder")
fi

# ---------------------------------------------------------------------------
# 2. Git branch - name, * if dirty, arrows if ahead/behind. Omit if not a
#    git repo.
# ---------------------------------------------------------------------------
if ! is_empty "$cwd" && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if ! is_empty "$branch"; then
    dirty=""
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
      dirty="*"
    fi

    ahead="$(git -C "$cwd" rev-list --count '@{u}..HEAD' 2>/dev/null)"
    behind="$(git -C "$cwd" rev-list --count 'HEAD..@{u}' 2>/dev/null)"
    arrows=""
    if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then
      arrows="${arrows}↑"
    fi
    if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
      arrows="${arrows}↓"
    fi

    segments+=("${branch}${dirty}${arrows}")
  fi
fi

# ---------------------------------------------------------------------------
# 3. Model display name - colored (opus=yellow, sonnet=cyan, haiku=green,
#    fable=magenta, other=bold)
# ---------------------------------------------------------------------------
model_name="$(get '.model.display_name // empty')"
model_id="$(get '.model.id // empty')"
if ! is_empty "$model_name"; then
  combined="$(printf '%s %s' "$model_id" "$model_name" | tr '[:upper:]' '[:lower:]')"
  case "$combined" in
    *opus*) color="33" ;;
    *sonnet*) color="36" ;;
    *haiku*) color="32" ;;
    *fable*) color="35" ;;
    *) color="1" ;;
  esac
  segments+=("$(printf '\033[%sm%s\033[0m' "$color" "$model_name")")
fi

# ---------------------------------------------------------------------------
# 4. Effort level - always shown
# ---------------------------------------------------------------------------
effort="$(get '.effort.level // empty')"
if is_empty "$effort"; then
  effort="off"
fi
segments+=("$effort")

# ---------------------------------------------------------------------------
# 5. Permission mode - raw name
# ---------------------------------------------------------------------------
perm_mode="$(get '.permissionMode // .permission_mode // empty')"
if ! is_empty "$perm_mode"; then
  segments+=("$perm_mode")
fi

# ---------------------------------------------------------------------------
# 6. Context bar - 10 block bar reflecting used_percentage + printed %
# ---------------------------------------------------------------------------
used_pct="$(get '.context_window.used_percentage // empty')"
if ! is_empty "$used_pct"; then
  filled="$(awk -v p="$used_pct" 'BEGIN{n=int((p/10)+0.5); if(n>10)n=10; if(n<0)n=0; print n}')"
  empty_blocks=$((10 - filled))

  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i+1)); done
  i=0
  while [ "$i" -lt "$empty_blocks" ]; do bar="${bar}░"; i=$((i+1)); done

  bar_color="$(awk -v p="$used_pct" 'BEGIN{
    if (p < 50) print "32";
    else if (p < 70) print "33";
    else if (p < 90) print "38;5;208";
    else print "31";
  }')"

  pct_display="$(awk -v p="$used_pct" 'BEGIN{printf "%.0f", p}')"
  segments+=("$(printf '\033[%sm%s %s%%\033[0m' "$bar_color" "$bar" "$pct_display")")
fi

# ---------------------------------------------------------------------------
# 7. Tokens used in context window
# ---------------------------------------------------------------------------
total_input="$(get '.context_window.total_input_tokens // empty')"
if ! is_empty "$total_input"; then
  tok_fmt="$(awk -v t="$total_input" 'BEGIN{
    if (t >= 1000) printf "%.1fk", t/1000;
    else printf "%d", t;
  }')"
  segments+=("${tok_fmt} tok")
fi

# ---------------------------------------------------------------------------
# 8. Cache hit % - cache:<N>%
# ---------------------------------------------------------------------------
cache_pct="$(get '.context_window.cache_hit_percentage // empty')"
if is_empty "$cache_pct"; then
  cache_read="$(get '.context_window.current_usage.cache_read_input_tokens // empty')"
  total_in="$(get '.context_window.total_input_tokens // empty')"
  if ! is_empty "$cache_read" && ! is_empty "$total_in"; then
    cache_pct="$(awk -v r="$cache_read" -v t="$total_in" 'BEGIN{
      if (t > 0) printf "%.0f", (r/t)*100; else print "";
    }')"
  fi
fi
if ! is_empty "$cache_pct"; then
  segments+=("cache:${cache_pct}%")
fi

# ---------------------------------------------------------------------------
# 9. Cost - $x.xx
# ---------------------------------------------------------------------------
cost="$(get '.cost.total_cost_usd // empty')"
if ! is_empty "$cost"; then
  cost_fmt="$(awk -v c="$cost" 'BEGIN{printf "$%.2f", c}')"
  segments+=("$cost_fmt")
fi

# ---------------------------------------------------------------------------
# 10. Rate limit - always shown, "Rate Limit N% (resets HH:MM)"
# ---------------------------------------------------------------------------
rl_pct="$(get '.rate_limits.five_hour.used_percentage // empty')"
rl_reset="$(get '.rate_limits.five_hour.resets_at // empty')"
if ! is_empty "$rl_pct"; then
  rl_pct_fmt="$(awk -v p="$rl_pct" 'BEGIN{printf "%.0f", p}')"
  reset_time=""
  if ! is_empty "$rl_reset"; then
    reset_time="$(date -r "${rl_reset%.*}" '+%H:%M' 2>/dev/null)"
  fi
  if is_empty "$reset_time"; then
    reset_time="N/A"
  fi
  segments+=("Rate Limit ${rl_pct_fmt}% (resets ${reset_time})")
else
  segments+=("Rate Limit N/A")
fi

# ---------------------------------------------------------------------------
# Join segments with " | "
# ---------------------------------------------------------------------------
output=""
for seg in "${segments[@]}"; do
  if [ -z "$output" ]; then
    output="$seg"
  else
    output="${output} | ${seg}"
  fi
done

printf '%s' "$output"
