#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="incident-report.sh"
WS_HELP_TITLE="incident-report.sh — production incident snapshot"
WS_HELP_BODY="Usage: ./incident-report.sh <INCIDENT-ID> [-h|--help]

Example: ./incident-report.sh INC-1024

Creates incident-<ID>/ with status, health, versions, git state, env, logs, system info."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

INC_ID="${1:-}"
if [[ -z "$INC_ID" || "$INC_ID" == -* ]]; then
  echo "Usage: ./incident-report.sh <INCIDENT-ID>" >&2
  exit "$EXIT_USAGE"
fi

OUT_DIR="$ROOT/incident-${INC_ID}"
mkdir -p "$OUT_DIR"

ws_header "Incident snapshot → $OUT_DIR"

capture() {
  local name="$1"
  shift
  ws_log_info "Capturing $name"
  "$@" > "$OUT_DIR/${name}.txt" 2>&1 || true
}

capture status "$ROOT/status.sh"
capture health "$ROOT/health.sh"
capture versions "$ROOT/version.sh"
capture env-check "$ROOT/env-check.sh"

report_git_state() {
  local label="$1" dir="$2"
  local path
  path="$(repo_dir "$dir")"
  if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "=== $label ($dir) ==="
    git -C "$path" status
    echo ""
    git -C "$path" log -5 --oneline
    echo ""
  fi
}

{
  echo "Incident: $INC_ID"
  echo "Captured: $(date -Iseconds)"
  echo "Workspace: $WORKSPACE_ROOT"
  echo ""
  foreach_repo report_git_state
} > "$OUT_DIR/git-state.txt"

LOG_DIR="$(ws_run_dir)/logs"
{
  echo "Log directory: $LOG_DIR"
  echo ""
  for log in backend web admin support; do
    f="$LOG_DIR/${log}.log"
    echo "=== $log (last 100 lines) ==="
    if [[ -f "$f" ]]; then
      tail -100 "$f"
    else
      echo "(no log file)"
    fi
    echo ""
  done
} > "$OUT_DIR/recent-logs.txt"

{
  echo "hostname: $(hostname 2>/dev/null || echo unknown)"
  echo "date: $(date -Iseconds)"
  uname -a 2>/dev/null || true
  echo ""
  df -h "$WORKSPACE_ROOT" 2>/dev/null || true
  echo ""
  free -h 2>/dev/null || true
  echo ""
  if command -v ss >/dev/null 2>&1; then
    ss -tln | grep -E ":(${PORT_BACKEND}|${PORT_WEB}|${PORT_ADMIN}|${PORT_SUPPORT}) " || echo "(no dev ports listening)"
  fi
} > "$OUT_DIR/system-info.txt"

cat > "$OUT_DIR/README.txt" <<EOF
LinkKin Incident Snapshot: $INC_ID
Generated: $(date -Iseconds)

Files:
  status.txt       — service status (expected vs actual)
  health.txt       — live health checks
  versions.txt     — git branch / version / commit per repo
  git-state.txt    — git status + recent commits
  env-check.txt    — .env.example vs .env diff
  recent-logs.txt  — last 100 lines per dev service log
  system-info.txt  — disk, memory, ports

Attach this folder to the incident ticket.
EOF

ws_log_ok "Incident bundle: $OUT_DIR"
ls -la "$OUT_DIR"
exit "$EXIT_OK"
