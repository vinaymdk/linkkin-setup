#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="status.sh"
WS_HELP_TITLE="status.sh — development service status"
WS_HELP_BODY="Usage: ./status.sh [-h|--help]

Shows expected vs actual state for dev services (from workspace.yml).
Exit 1 if a required service (expected: running) is not running."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

MISMATCH=0

service_actual_state() {
  local key="$1" pid_var="$2"
  case "$key" in
    backend|web|admin|support)
      local pid
      pid="$(ws_read_pid "$pid_var" 2>/dev/null || true)"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "running|$pid"
      else
        echo "stopped|"
      fi
      ;;
    mobile)
      if pgrep -f "flutter run" >/dev/null 2>&1; then
        echo "running|$(pgrep -f 'flutter run' | head -1)"
      else
        echo "stopped|"
      fi
      ;;
    redis)
      if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        echo "running|"
      else
        echo "stopped|"
      fi
      ;;
    postgresql)
      if command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null; then
        echo "running|"
      elif systemctl is-active postgresql >/dev/null 2>&1; then
        echo "running|"
      else
        echo "stopped|"
      fi
      ;;
    radio)
      if systemctl is-active icecast2 >/dev/null 2>&1; then
        echo "running|"
      else
        echo "stopped|"
      fi
      ;;
    *)
      echo "unknown|"
      ;;
  esac
}

print_expected_actual() {
  local label="$1" key="$2" pid_var="$3" expected="$4"
  local actual extra pid
  IFS='|' read -r actual extra <<< "$(service_actual_state "$key" "$pid_var")"

  echo "$label"
  echo "  Expected: ${expected^}"
  printf "  Actual:   %s" "${actual^}"
  [[ -n "$extra" ]] && printf " (PID $extra)"
  echo ""

  local ok=0
  case "$expected" in
    running)
      [[ "$actual" == "running" ]] && ok=1
      ;;
    stopped)
      [[ "$actual" == "stopped" ]] && ok=1
      ;;
    optional)
      ok=1
      ;;
    *)
      ok=1
      ;;
  esac

  if [[ "$ok" == "1" ]]; then
    echo -e "  ${GREEN}✓${NC}"
  else
    echo -e "  ${RED}✗${NC}"
    MISMATCH=1
  fi
  echo "-----------"
}

ws_header "Status (expected vs actual)"

while IFS='|' read -r key label pid_var expected; do
  [[ -n "$key" ]] || continue
  print_expected_actual "$label" "$key" "$pid_var" "$expected"
done < <(ws_list_service_expectations)

echo ""
if [[ "$MISMATCH" -eq 0 ]]; then
  echo -e "${GREEN}✓ All expected services match${NC}"
  exit "$EXIT_OK"
fi
echo -e "${YELLOW}⚠ Service state mismatch — run ./linkkin-run.sh or check infra${NC}"
exit "$EXIT_FAIL"
