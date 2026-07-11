#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="health.sh"
WS_HELP_TITLE="health.sh — live service health check"
WS_HELP_BODY="Usage: ./health.sh [-h|--help]

Checks API, web, database, Redis, WebSocket, Icecast, Firebase, disk, memory.
URLs from workspace.yml (override with API_URL, WEB_URL, ICECAST_URL)."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

API_URL="${API_URL:-$URL_BACKEND}"
WEB_URL="${WEB_URL:-$URL_WEB}"
ICECAST_URL="${ICECAST_URL:-$URL_ICECAST}"

FAIL=0

check_line() {
  local label="$1" ok="$2" detail="${3:-}" critical="${4:-1}"
  if [[ "$ok" == "1" ]]; then
    printf "  %-22s ${GREEN}✓${NC}" "$label"
    [[ -n "$detail" ]] && printf "  %s" "$detail"
    echo ""
  else
    if [[ "$critical" == "1" ]]; then
      printf "  %-22s ${RED}✗${NC}" "$label"
      FAIL=1
    else
      printf "  %-22s ${YELLOW}⚠${NC}" "$label"
    fi
    [[ -n "$detail" ]] && printf "  %s" "$detail"
    echo ""
  fi
}

ws_header "Health Check"

# Backend API
if command -v curl >/dev/null 2>&1; then
  if resp="$(curl -sf -m 5 "$API_URL/health" 2>/dev/null)"; then
    check_line "Backend API" 1 "$API_URL/health"
  else
    check_line "Backend API" 0 "$API_URL (not responding)"
  fi

  if curl -sf -m 5 "$WEB_URL" >/dev/null 2>&1; then
    check_line "Web" 1 "$WEB_URL"
  else
    check_line "Web" 0 "$WEB_URL (not responding — run ./linkkin-run.sh)" 0
  fi

  if curl -sf -m 5 "$API_URL/health/ready" 2>/dev/null | grep -q '"database":"up"'; then
    check_line "Database" 1 "via /health/ready"
  else
    check_line "Database" 0 "via /health/ready"
  fi
else
  ws_log_warn "curl not installed — skipping HTTP checks"
fi

# Redis
if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
  check_line "Redis" 1 "$(redis-cli ping)"
else
  check_line "Redis" 0 "optional — in-memory fallback" 0
fi

# WebSocket (port open on API host)
ws_host="${API_URL#*://}"
ws_host="${ws_host%%/*}"
ws_port="${ws_host##*:}"
ws_host="${ws_host%%:*}"
[[ "$ws_port" == "$ws_host" ]] && ws_port=8000
if command -v nc >/dev/null 2>&1 && nc -z "$ws_host" "$ws_port" 2>/dev/null; then
  check_line "WebSocket" 1 "API port $ws_port open (WS: /ws)"
elif command -v ss >/dev/null 2>&1 && ss -tln | grep -q ":${ws_port} "; then
  check_line "WebSocket" 1 "API port $ws_port open (WS: /ws)"
else
  check_line "WebSocket" 0 "port $ws_port" 0
fi

# Icecast
if command -v curl >/dev/null 2>&1 && curl -sf -m 3 -o /dev/null "$ICECAST_URL" 2>/dev/null; then
  check_line "Icecast" 1 "$ICECAST_URL"
else
  check_line "Icecast" 0 "$ICECAST_URL (radio server optional)" 0
fi

# Firebase
fb="$(repo_dir ../linkkin-backend)/firebase-service-account.json"
if [[ -f "$fb" ]]; then
  check_line "Firebase" 1 "service account present"
else
  check_line "Firebase" 0 "firebase-service-account.json missing" 0
fi

# Disk
if command -v df >/dev/null 2>&1; then
  disk_use="$(df -h "$WORKSPACE_ROOT" | awk 'NR==2 {print $5 " used (" $4 " free)"}')"
  pct="$(df "$WORKSPACE_ROOT" | awk 'NR==2 {gsub(/%/,""); print $5}')"
  if [[ "${pct:-0}" -lt 90 ]]; then
    check_line "Disk" 1 "$disk_use"
  else
    check_line "Disk" 0 "$disk_use (low space)"
  fi
fi

# Memory
if command -v free >/dev/null 2>&1; then
  mem="$(free -h | awk '/^Mem:/ {print $3 "/" $2 " used"}')"
  check_line "Memory" 1 "$mem"
fi

echo ""
echo "--------------------------"
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}✓ HEALTHY${NC}"
else
  echo -e "${YELLOW}⚠ SOME CHECKS FAILED${NC} (optional services may show ✗ in dev)"
  exit "$EXIT_FAIL"
fi

exit "$EXIT_OK"
