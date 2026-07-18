#!/usr/bin/env bash
# Captures stdout/stderr (print()/NSLog) from an app on a wirelessly paired
# iOS test device by wrapping `xcrun devicectl device process launch --console`.
#
# Known limitation: devicectl has no general syslog/unified-log stream. This
# only sees output the app writes to stdout/stderr, and only from a fresh
# launch — any running instance of the app is terminated and relaunched. It
# will NOT see os_log/Logger output. If the target app only logs that way,
# add print() calls at the events you want visible.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: device-console.sh [--device <name|udid>] [--timeout <seconds>] <bundle-id-or-app-name>

  --device   Target device name or UDID. Required if more than one paired
             device is available; auto-detected otherwise.
  --timeout  Seconds to capture console output before devicectl stops the
             command (default: 30).

<bundle-id-or-app-name> may be an exact bundle identifier (e.g.
ca.hewick.CarDodge) or a case-insensitive substring of the app's display
name (e.g. "car dodge") — resolved via `devicectl device info apps`.

Relaunches the app fresh (terminating any running instance) and prints its
stdout/stderr for <timeout> seconds. Exit code 2 after the timeout fires is
expected — it just means the capture window closed while the app kept running.
EOF
}

device_arg=""
timeout=30
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) device_arg="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) target="$1"; shift ;;
  esac
done

if [[ -z "$target" ]]; then
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required (brew install jq)" >&2
  exit 1
fi

# bash 3.2 (macOS default) has no mapfile/readarray — collect lines by hand.
read_lines() {
  local __out_var="$1"
  local __line
  eval "$__out_var=()"
  while IFS= read -r __line; do
    [[ -n "$__line" ]] && eval "$__out_var+=(\"\$__line\")"
  done
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# --- resolve device -----------------------------------------------------
xcrun devicectl list devices --json-output "$workdir/devices.json" >/dev/null

if [[ -n "$device_arg" ]]; then
  device_id="$(jq -r --arg q "$device_arg" '
    .result.devices[]
    | select(.identifier == $q or .deviceProperties.name == $q)
    | .identifier' "$workdir/devices.json" | head -n1)"
  if [[ -z "$device_id" ]]; then
    echo "error: no paired device matching '$device_arg'" >&2
    exit 1
  fi
else
  read_lines paired < <(jq -r '
    .result.devices[]
    | select(.connectionProperties.pairingState == "paired")
    | .identifier' "$workdir/devices.json")
  if [[ ${#paired[@]} -eq 0 ]]; then
    echo "error: no paired devices found. Pair the iPhone with Xcode first (Window > Devices and Simulators)." >&2
    exit 1
  elif [[ ${#paired[@]} -gt 1 ]]; then
    echo "error: multiple paired devices found, pass --device <name|udid>:" >&2
    jq -r '.result.devices[] | select(.connectionProperties.pairingState == "paired") | "  \(.deviceProperties.name)  \(.identifier)"' "$workdir/devices.json" >&2
    exit 1
  fi
  device_id="${paired[0]}"
fi

# --- resolve bundle id ---------------------------------------------------
xcrun devicectl device info apps --device "$device_id" --bundle-id "$target" --json-output "$workdir/exact.json" >/dev/null
bundle_id="$(jq -r '.result.apps[0].bundleIdentifier // empty' "$workdir/exact.json")"

if [[ -z "$bundle_id" ]]; then
  xcrun devicectl device info apps --device "$device_id" --json-output "$workdir/apps.json" >/dev/null
  read_lines matches < <(jq -r --arg q "$target" '
    .result.apps[]
    | select(.name | ascii_downcase | contains($q | ascii_downcase))
    | .bundleIdentifier' "$workdir/apps.json")
  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "error: no installed developer app matching '$target' on this device. Installed apps:" >&2
    jq -r '.result.apps[] | "  \(.name)  \(.bundleIdentifier)"' "$workdir/apps.json" >&2
    exit 1
  elif [[ ${#matches[@]} -gt 1 ]]; then
    echo "error: multiple installed apps match '$target', use the exact bundle id:" >&2
    jq -r --arg q "$target" '.result.apps[] | select(.name | ascii_downcase | contains($q | ascii_downcase)) | "  \(.name)  \(.bundleIdentifier)"' "$workdir/apps.json" >&2
    exit 1
  fi
  bundle_id="${matches[0]}"
fi

echo "device: $device_id" >&2
echo "app: $bundle_id" >&2
echo "capturing stdout/stderr for ${timeout}s (fresh launch, terminates any running instance)..." >&2
echo "---" >&2

set +e
xcrun devicectl device process launch \
  --device "$device_id" \
  --console \
  --terminate-existing \
  -t "$timeout" \
  "$bundle_id"
exit_code=$?
set -e

if [[ $exit_code -eq 2 ]]; then
  exit 0 # expected: the capture window closed while the app kept running
fi
exit "$exit_code"
