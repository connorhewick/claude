#!/usr/bin/env bash
# Installs one, several, or all components from this repo into ~/.claude/
# (or $CLAUDE_CONFIG_DIR, if set).
#
# Usage:
#   ./install.sh all                  install every component
#   ./install.sh write-prd planner    install just the named components
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=components.sh
source "$here/components.sh"
# shellcheck source=common.sh
source "$here/common.sh"

usage() {
  echo "Usage: $0 all | <component> [<component> ...]" >&2
  echo "Known components:" >&2
  printf '  %s\n' "${ALL_COMPONENTS[@]}" >&2
}

# One function per component. Each just delegates to the typed helper in
# common.sh for its extension point (skill/agent/rule/command/statusline).
install_write_prd()           { install_skill  write-prd; }
install_spec_first_planning() { install_skill  spec-first-planning; }
install_write_adr()           { install_skill  write-adr; }
install_prepare_pr()          { install_skill  prepare-pr; }
install_split_commits()       { install_skill  split-commits; }
install_device_logs()         { install_skill  device-logs; }
install_port_ios_to_web()     { install_skill  port-ios-to-web; }
install_port_web_to_ios()     { install_skill  port-web-to-ios; }
install_doc_sync()            { install_skill  doc-sync; }
install_planner()             { install_agent  planner; }
install_explorer()            { install_agent  explorer; }
install_reviewer()            { install_agent  reviewer; }
install_doc_writer()          { install_agent  doc-writer; }
install_docs()                { install_rule   docs; }
install_statusline()          { install_statusline_file statusline; }
install_global_rules()        { install_claude_md_file global-rules; }

run_installer() {
  case "$1" in
    write-prd)            install_write_prd ;;
    spec-first-planning)  install_spec_first_planning ;;
    write-adr)            install_write_adr ;;
    prepare-pr)           install_prepare_pr ;;
    split-commits)        install_split_commits ;;
    device-logs)          install_device_logs ;;
    port-ios-to-web)      install_port_ios_to_web ;;
    port-web-to-ios)      install_port_web_to_ios ;;
    doc-sync)             install_doc_sync ;;
    planner)              install_planner ;;
    explorer)             install_explorer ;;
    reviewer)             install_reviewer ;;
    doc-writer)           install_doc_writer ;;
    docs)                 install_docs ;;
    statusline)           install_statusline ;;
    global-rules)         install_global_rules ;;
    *)
      echo "install.sh: unknown component '$1'" >&2
      exit 1
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

targets=("$@")
if [[ "${targets[0]}" == "all" ]]; then
  targets=("${ALL_COMPONENTS[@]}")
fi

for name in "${targets[@]}"; do
  if ! is_known_component "$name"; then
    echo "install.sh: unknown component '$name'" >&2
    usage
    exit 1
  fi
done

for name in "${targets[@]}"; do
  run_installer "$name"
done
