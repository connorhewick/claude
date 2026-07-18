#!/usr/bin/env bash
# Removes one, several, or all components previously installed from this repo
# into ~/.claude/ (or $CLAUDE_CONFIG_DIR, if set). Each uninstall_<name>()
# removes exactly what the matching install_<name>() in install.sh wrote —
# nothing more.
#
# Usage:
#   ./uninstall.sh all                  remove every component
#   ./uninstall.sh write-prd planner    remove just the named components
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/components.sh
source "$here/lib/components.sh"
# shellcheck source=lib/common.sh
source "$here/lib/common.sh"

usage() {
  echo "Usage: $0 all | <component> [<component> ...]" >&2
  echo "Known components:" >&2
  printf '  %s\n' "${ALL_COMPONENTS[@]}" >&2
}

uninstall_write_prd()           { uninstall_skill  write-prd; }
uninstall_spec_first_planning() { uninstall_skill  spec-first-planning; }
uninstall_write_adr()           { uninstall_skill  write-adr; }
uninstall_prepare_pr()          { uninstall_skill  prepare-pr; }
uninstall_split_commits()       { uninstall_skill  split-commits; }
uninstall_device_logs()         { uninstall_skill  device-logs; }
uninstall_port_ios_to_web()     { uninstall_skill  port-ios-to-web; }
uninstall_port_web_to_ios()     { uninstall_skill  port-web-to-ios; }
uninstall_doc_sync()            { uninstall_skill  doc-sync; }
uninstall_planner()             { uninstall_agent  planner; }
uninstall_explorer()            { uninstall_agent  explorer; }
uninstall_reviewer()            { uninstall_agent  reviewer; }
uninstall_doc_writer()          { uninstall_agent  doc-writer; }
uninstall_docs()                { uninstall_rule   docs; }
uninstall_walkthroughs()        { uninstall_rule   walkthroughs; }
uninstall_statusline()          { uninstall_statusline_file statusline; }

run_uninstaller() {
  case "$1" in
    write-prd)            uninstall_write_prd ;;
    spec-first-planning)  uninstall_spec_first_planning ;;
    write-adr)            uninstall_write_adr ;;
    prepare-pr)           uninstall_prepare_pr ;;
    split-commits)        uninstall_split_commits ;;
    device-logs)          uninstall_device_logs ;;
    port-ios-to-web)      uninstall_port_ios_to_web ;;
    port-web-to-ios)      uninstall_port_web_to_ios ;;
    doc-sync)             uninstall_doc_sync ;;
    planner)              uninstall_planner ;;
    explorer)             uninstall_explorer ;;
    reviewer)             uninstall_reviewer ;;
    doc-writer)           uninstall_doc_writer ;;
    docs)                 uninstall_docs ;;
    walkthroughs)         uninstall_walkthroughs ;;
    statusline)           uninstall_statusline ;;
    *)
      echo "uninstall.sh: unknown component '$1'" >&2
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
    echo "uninstall.sh: unknown component '$name'" >&2
    usage
    exit 1
  fi
done

for name in "${targets[@]}"; do
  run_uninstaller "$name"
done
