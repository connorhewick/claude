---
name: device-logs
description: >
  Capture console output (print()/NSLog stdout+stderr) from an app on a
  wirelessly paired iOS test device, using Xcode's built-in `xcrun devicectl`
  — no extra installs. Triggers for: "show me the device logs", "what's the
  iPhone printing", "check the console on my test device", "see logs from
  the app on my phone". Relaunches the target app fresh and captures its
  output for a fixed window; it does NOT stream the full unified log
  (os_log/Logger), only what the app writes to stdout/stderr — see
  Limitations below before assuming a silent capture means nothing happened.
allowed-tools: Bash(xcrun devicectl *), Bash(jq *), Bash(.claude/skills/device-logs/scripts/device-console.sh *)
---

Pulls console output from a wirelessly connected iOS test device (already paired via
Xcode — Window > Devices and Simulators) straight into the Claude Code session, via
`xcrun devicectl`. No `idevicesyslog`/`pymobiledevice3`/Homebrew required.

## Invocation

```
.claude/skills/device-logs/scripts/device-console.sh [--device <name|udid>] [--timeout <seconds>] <bundle-id-or-app-name>
```

- `<bundle-id-or-app-name>` — an exact bundle id (`ca.hewick.CarDodge`) or a
  case-insensitive substring of the app's display name (`"car dodge"`). Resolved
  against the device's installed developer apps.
- `--device` — only needed when more than one paired device is available.
- `--timeout` — capture window in seconds (default 30). The script normalizes
  devicectl's expected post-timeout exit code (2) to 0 — a timeout after the
  window closes is success, not failure.

Run it directly via Bash. It prints device/app resolution to stderr and the
captured console output to stdout, in real time.

## Limitations — read before trusting an empty result

`devicectl` has no general syslog/unified-log stream (no equivalent of
Console.app or `idevicesyslog`). This wraps `devicectl device process launch
--console`, which:

- Only captures what the app writes to **stdout/stderr** (`print()`, `NSLog`).
  It does **not** see `os_log`/`Logger`-based structured logging — the vast
  majority of what a modern SwiftUI/UIKit app logs by default.
- Only captures from a **fresh launch** — it terminates any already-running
  instance of the app and relaunches it. You can't attach to a session already
  in progress.

An empty capture is therefore not proof nothing happened — it may just mean the
app doesn't log to stdout at all. Verified against a real device: launching an
app with zero `print()`/`NSLog` calls anywhere in its source produced a
silent, timed-out capture even though the app runs fine.

**If a capture comes back empty and you need visibility into it, add
`print("[AppName] <event>")` calls at the events you care about** (app launch,
screen/state transitions, request/response boundaries, caught errors) rather
than assuming the tool is broken. Prefer instrumenting boundaries that fire
unconditionally on launch (e.g. the app's `init`) first — that's enough to
confirm the plumbing works before chasing an interaction-gated code path. Wrap
additions in `#if DEBUG ... #endif` so they don't ship in Release/App Store
builds.

`devicectl`'s tunnel/DDI connection can also get backlogged after several rapid
launch cycles in a row: the CLI reports "Command timeout... aborting" and never
prints "Launched application...", even though the app actually launched (check
`xcrun devicectl device info processes --device <id> --json-output <path>`,
field `.result.runningProcesses`, for a live PID). If a capture looks stuck
with no launch confirmation at all, terminate the orphaned process
(`devicectl device process terminate --device <id> --pid <pid>`), wait a few
seconds, and retry — don't read it as your logging being broken.

If full unified-log capture (os_log/Logger, no source changes needed) is ever
required, the alternative is installing `pymobiledevice3` (`pip3 install
pymobiledevice3`) and using its syslog relay — that trade-off (one more
dependency, in exchange for not needing to touch app source) was deliberately
declined in favor of the zero-install devicectl approach; revisit only if that
constraint changes.

## Design notes

- Device/app resolution shells out to `devicectl ... --json-output` and parses
  with `jq` (present on stock macOS as of recent Xcode installs).
- Written for bash 3.2 (macOS's default `/bin/bash`) — no `mapfile`/`readarray`.
