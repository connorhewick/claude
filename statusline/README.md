# statusline

**Type:** statusline · installs to `~/.claude/statuslines/statusline.sh` (+ patches
`~/.claude/settings.json`'s `.statusLine`)

A single pipe-delimited status line, ANSI colors always on. Reads the session JSON Claude Code
pipes in on stdin and shows, left to right when present: current folder, git branch (`*` if
dirty, `↑`/`↓` if ahead/behind upstream), model name (colored by model), effort level, permission
mode, a 10-block context-usage bar (colored by thresholds), tokens used, cache-hit %, session
cost, and the 5-hour rate-limit usage with reset time.

Install clears any previous `.statusLine` this component set; it never touches a statusline you
configured some other way, and uninstalling only clears `.statusLine` if it still points here.
