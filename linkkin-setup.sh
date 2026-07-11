#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="linkkin-setup.sh"
WS_HELP_TITLE="linkkin-setup.sh — first-time setup for all repos"
WS_HELP_BODY="Usage: ./linkkin-setup.sh [-h|--help]

Runs ./setup.sh in each repository (order from workspace.yml)."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

ws_header "Setup (all repositories)"

FAILED=0

do_setup() {
  local label="$1" dir="$2"
  echo -e "${CYAN}--- $label ---${NC}"
  if run_repo_script "$dir" "setup.sh"; then
    ws_log_ok "$label setup complete"
  else
    ws_log_fail "$label setup failed"
    FAILED=1
  fi
  echo ""
}

foreach_repo do_setup

if [[ "$FAILED" -eq 0 ]]; then
  ws_log_ok "All repositories set up"
  ws_log_info "Run ./linkkin-doctor.sh to verify"
else
  ws_log_fail "Some repositories failed — see output above"
  exit "$EXIT_FAIL"
fi

exit "$EXIT_OK"
