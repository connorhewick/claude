# device-logs

**Type:** skill · installs to `~/.claude/skills/device-logs/`

Captures console output (`print()`/`NSLog` stdout+stderr) from an app on a wirelessly paired iOS
test device using Xcode's built-in `xcrun devicectl` — no extra installs. Relaunches the target
app fresh and captures its output for a fixed window. Does **not** stream the full unified log
(`os_log`/`Logger`), only stdout/stderr — see the skill's Limitations section before assuming a
silent capture means nothing happened.

Auto-invoked for requests like "show me the device logs" or "what's the iPhone printing".
Carries a supporting script (`scripts/device-console.sh`) that installs alongside `SKILL.md`.
