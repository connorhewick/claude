#!/usr/bin/env bash
# Single source of truth: every component this repo knows how to install.
# Sourced by both install.sh and uninstall.sh — do not duplicate this list
# anywhere else.
#
# Adding a component means touching four things: this array, the
# is_known_component() case below, an install_<name>()/uninstall_<name>()
# function pair (in install.sh/uninstall.sh respectively), and the matching
# dispatch case in each script's run_installer()/run_uninstaller().

ALL_COMPONENTS=(
  write-prd
  write-adr
  write-tdd
  prepare-pr
  split-commits
  device-logs
  port-ios-to-web
  port-web-to-ios
  doc-sync
  session-handoff
  component-review
  ios-engineering
  python-engineering
  java-engineering
  harness-portability
  issue-workplan
  harness-scaffold
  statusline
  global-rules
  git-rules
  swiftui-rules
  documentation-rules
)

# Every rule-type component, in the shared rules/ directory. `install.sh rules`
# / `uninstall.sh rules` expand to exactly this list — update it when adding a
# new rule component, alongside its entry in ALL_COMPONENTS above.
RULE_COMPONENTS=(
  git-rules
  swiftui-rules
  documentation-rules
)

is_known_component() {
  case "$1" in
    write-prd|write-adr|write-tdd|prepare-pr|split-commits| \
    device-logs|port-ios-to-web|port-web-to-ios|doc-sync| \
    session-handoff|component-review|ios-engineering|python-engineering|java-engineering| \
    harness-portability|issue-workplan|harness-scaffold|statusline|global-rules|git-rules| \
    swiftui-rules|documentation-rules)
      return 0 ;;
    *)
      return 1 ;;
  esac
}
