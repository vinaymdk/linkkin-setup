#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="workspace-logs.sh"
WS_HELP_TITLE="workspace-logs.sh — aggregated live logs"
WS_HELP_BODY="Usage: ./workspace-logs.sh [-h|--help]

Tails combined logs from backend, web, admin, and support dev servers.
Logs: .linkkin-run/logs/"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

LOG_DIR="$(ws_run_dir)/logs"
mkdir -p "$LOG_DIR"

prefix_log() {
  local tag="$1" file="$2"
  [[ -f "$file" ]] || touch "$file"
  tail -F "$file" 2>/dev/null | while IFS= read -r line; do
    echo "[$tag] $line"
  done
}

ws_header "Live logs (Ctrl+C to stop)"
echo "Log directory: $LOG_DIR"
echo ""

if ! command -v tail >/dev/null 2>&1; then
  ws_log_fail "tail not found"
  exit "$EXIT_FAIL"
fi

# Run prefix_log for each service in background; wait
prefix_log "backend" "$LOG_DIR/backend.log" &
prefix_log "web" "$LOG_DIR/web.log" &
prefix_log "admin" "$LOG_DIR/admin.log" &
prefix_log "support" "$LOG_DIR/support.log" &
wait
