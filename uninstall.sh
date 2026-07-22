#!/usr/bin/env bash
# Removes one, several, or all components previously installed from this repo
# into ~/.claude/ (or $CLAUDE_CONFIG_DIR, if set). Each uninstall_<name>()
# removes exactly what the matching install_<name>() in install.sh wrote —
# nothing more.
#
# Usage:
#   ./uninstall.sh all                  remove every component
#   ./uninstall.sh write-prd write-adr  remove just the named components
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/components.sh"
source "$here/common.sh"

usage() {
  echo "Usage: $0 all | <component> [<component> ...]" >&2
  echo "Known components:" >&2
  printf '  %s\n' "${ALL_COMPONENTS[@]}" >&2
}

uninstall_write_prd()           { uninstall_skill  write-prd; }
uninstall_write_adr()           { uninstall_skill  write-adr; }
uninstall_prepare_pr()          { uninstall_skill  prepare-pr; }
uninstall_split_commits()       { uninstall_skill  split-commits; }
uninstall_device_logs()         { uninstall_skill  device-logs; }
uninstall_port_ios_to_web()     { uninstall_skill  port-ios-to-web; }
uninstall_port_web_to_ios()     { uninstall_skill  port-web-to-ios; }
uninstall_doc_sync()            { uninstall_skill  doc-sync; }
uninstall_session_handoff()     { uninstall_skill  session-handoff; }
uninstall_component_review()    { uninstall_skill  component-review; }
uninstall_ios_engineering()     { uninstall_skill  ios-engineering; }
uninstall_harness_portability() { uninstall_skill  harness-portability; }
uninstall_issue_workplan()      { uninstall_skill  issue-workplan; }
uninstall_harness_scaffold()    { uninstall_skill  harness-scaffold; }
uninstall_statusline()          { uninstall_statusline_file statusline; }
uninstall_global_rules()        { uninstall_claude_md_file global-rules; }
uninstall_git_rules()           { uninstall_rule git-rules; }
uninstall_swiftui_rules()       { uninstall_rule swiftui-rules; }
uninstall_documentation_rules() { uninstall_rule documentation-rules; }

run_uninstaller() {
  case "$1" in
    write-prd)            uninstall_write_prd ;;
    write-adr)            uninstall_write_adr ;;
    prepare-pr)           uninstall_prepare_pr ;;
    split-commits)        uninstall_split_commits ;;
    device-logs)          uninstall_device_logs ;;
    port-ios-to-web)      uninstall_port_ios_to_web ;;
    port-web-to-ios)      uninstall_port_web_to_ios ;;
    doc-sync)             uninstall_doc_sync ;;
    session-handoff)      uninstall_session_handoff ;;
    component-review)     uninstall_component_review ;;
    ios-engineering)      uninstall_ios_engineering ;;
    harness-portability)  uninstall_harness_portability ;;
    issue-workplan)       uninstall_issue_workplan ;;
    harness-scaffold)     uninstall_harness_scaffold ;;
    statusline)           uninstall_statusline ;;
    global-rules)         uninstall_global_rules ;;
    git-rules)            uninstall_git_rules ;;
    swiftui-rules)        uninstall_swiftui_rules ;;
    documentation-rules)  uninstall_documentation_rules ;;
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
