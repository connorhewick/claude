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
  prepare-pr
  split-commits
  device-logs
  port-ios-to-web
  port-web-to-ios
  doc-sync
  statusline
  global-rules
)

is_known_component() {
  case "$1" in
    write-prd|write-adr|prepare-pr|split-commits| \
    device-logs|port-ios-to-web|port-web-to-ios|doc-sync| \
    statusline|global-rules)
      return 0 ;;
    *)
      return 1 ;;
  esac
}
