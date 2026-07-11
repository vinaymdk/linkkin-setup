#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="linkkin-doctor.sh"
WS_HELP_TITLE="linkkin-doctor.sh — verify all environments"
WS_HELP_BODY="Usage: ./linkkin-doctor.sh [-h|--help]

Runs ./doctor.sh in each repository and prints overall status."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

ws_header "Doctor (all repositories)"

FAILED=0

do_doctor() {
  local label="$1" dir="$2"
  if run_repo_script "$dir" "doctor.sh"; then
    pad_status_line "$label" "$(echo -e "${GREEN}✓${NC}")"
  else
    pad_status_line "$label" "$(echo -e "${RED}✗${NC}")"
    FAILED=1
  fi
}

foreach_repo do_doctor

echo ""
echo "--------------------------"
echo "Overall Status"
echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ READY${NC}"
else
  echo -e "${RED}✗ ISSUES FOUND${NC}"
  exit "$EXIT_FAIL"
fi

exit "$EXIT_OK"
