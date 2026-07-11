#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$ROOT/report.md}"
WS_SCRIPT_NAME="report.sh"
WS_HELP_TITLE="report.sh — generate workspace diagnostic report"
WS_HELP_BODY="Usage: ./report.sh [output.md] [-h|--help]

Generates report.md with versions, git status, health, doctor, disk, memory, ports, env."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && ws_show_help

ws_header "Generating report → $OUT"

{
  echo "# LinkKin Workspace Report"
  echo ""
  echo "Generated: $(date -Iseconds)"
  echo ""

  echo "## Versions"
  echo '```'
  "$ROOT/version.sh" 2>/dev/null || true
  echo '```'
  echo ""

  echo "## Git Status"
  echo '```'
  report_git_status() {
    local label="$1" dir="$2"
    local path branch commit dirty
    path="$(repo_dir "$dir")"
    if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch="$(git -C "$path" rev-parse --abbrev-ref HEAD)"
      commit="$(git -C "$path" rev-parse --short HEAD)"
      dirty=""
      [[ -n "$(git -C "$path" status --porcelain)" ]] && dirty=" (dirty)"
      echo "$label: $branch @ $commit$dirty"
    else
      echo "$label: not a git repo"
    fi
  }
  foreach_repo report_git_status
  echo '```'
  echo ""

  echo "## Health"
  echo '```'
  "$ROOT/health.sh" 2>&1 || true
  echo '```'
  echo ""

  echo "## Doctor"
  echo '```'
  "$ROOT/linkkin-doctor.sh" 2>&1 || true
  echo '```'
  echo ""

  echo "## Status"
  echo '```'
  "$ROOT/status.sh" 2>&1 || true
  echo '```'
  echo ""

  echo "## Disk & Memory"
  echo '```'
  df -h "$WORKSPACE_ROOT" 2>/dev/null || true
  free -h 2>/dev/null || true
  echo '```'
  echo ""

  echo "## Ports"
  echo '```'
  if command -v ss >/dev/null 2>&1; then
    ss -tln | grep -E ":(${PORT_BACKEND}|${PORT_WEB}|${PORT_ADMIN}|${PORT_SUPPORT}) " || echo "(no listeners)"
  fi
  echo '```'
  echo ""

  echo "## Environment"
  echo '```'
  "$ROOT/env-check.sh" 2>&1 | head -80 || true
  echo '```'
} > "$OUT"

ws_log_ok "Report written: $OUT"
exit "$EXIT_OK"
