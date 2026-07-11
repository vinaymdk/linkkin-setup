#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="linkkin-run.sh"
WS_HELP_TITLE="linkkin-run.sh — start development stack"
WS_HELP_BODY="$(cat <<EOF
Usage: ./linkkin-run.sh [-h|--help]

Starts backend, web, admin, and support in the background.
Ports from workspace.yml: backend ${PORT_BACKEND:-8000}, web ${PORT_WEB:-5173}, etc.

Options:
  USE_TMUX=1     Start in tmux session 'linkkin-dev'
  Stop:          ./scripts/stop-dev.sh
  Logs:          ./workspace-logs.sh
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

RUN_DIR="$(ws_run_dir)"
LOG_DIR="$RUN_DIR/logs"
PID_FILE="$RUN_DIR/pids.env"
USE_TMUX="${USE_TMUX:-0}"

mkdir -p "$LOG_DIR"

start_background() {
  local name="$1"
  local dir="$2"
  local cmd="$3"
  local pid_var="$4"
  local log="$LOG_DIR/${name}.log"
  local repo_path
  repo_path="$(repo_dir "$dir")"

  if [[ -f "$PID_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PID_FILE"
    local old_pid="${!pid_var:-}"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      ws_log_warn "$name already running (PID $old_pid)"
      return 0
    fi
  fi

  ws_log_info "Starting $name → $log"
  (cd "$repo_path" && nohup bash -c "$cmd" >>"$log" 2>&1 & echo $! > "$RUN_DIR/${name}.pid")
  local pid
  pid="$(cat "$RUN_DIR/${name}.pid")"
  echo "${pid_var}=$pid" >> "$PID_FILE"
  ws_log_ok "$name started (PID $pid)"
}

start_tmux() {
  local session="linkkin-dev"
  if tmux has-session -t "$session" 2>/dev/null; then
    ws_log_warn "tmux session '$session' already exists — attach with: tmux attach -t $session"
    exit "$EXIT_OK"
  fi

  tmux new-session -d -s "$session" -c "$(repo_dir ../linkkin-backend)" "npm run dev"
  tmux new-window -t "$session" -c "$(repo_dir ../linkkin-web)" "npm run dev"
  tmux new-window -t "$session" -c "$(repo_dir ../linkkin-admin)" "npm run dev"
  tmux new-window -t "$session" -c "$(repo_dir ../linkkin-support)" "npm run dev -- --port ${PORT_SUPPORT}"
  tmux new-window -t "$session" -c "$(repo_dir linkkin-radio)" "./run.sh || bash"

  ws_log_ok "tmux session '$session' started"
  echo ""
  echo "  tmux attach -t $session"
  echo "  tmux kill-session -t $session   # stop all"
  exit "$EXIT_OK"
}

ws_header "Run (development stack)"

if [[ "$USE_TMUX" == "1" ]] && command -v tmux >/dev/null 2>&1; then
  start_tmux
fi

: > "$PID_FILE"

start_background "backend" "../linkkin-backend" "npm run dev" "PID_BACKEND"
start_background "web" "../linkkin-web" "npm run dev" "PID_WEB"
start_background "admin" "../linkkin-admin" "npm run dev" "PID_ADMIN"
start_background "support" "../linkkin-support" "npm run dev -- --port ${PORT_SUPPORT}" "PID_SUPPORT"

echo ""
ws_log_ok "Development servers started in background"
echo ""
echo "  Backend  → $URL_BACKEND"
echo "  Web      → $URL_WEB"
echo "  Admin    → $URL_ADMIN"
echo "  Support  → $URL_SUPPORT"
echo ""
echo "  Logs:    $LOG_DIR/"
echo "  Stop:    ./scripts/stop-dev.sh"
echo "  Tail:    ./workspace-logs.sh"
echo ""
ws_log_info "Mobile: cd linkkin-mobile && ./run.sh  (interactive)"
ws_log_info "Radio:  cd linkkin-radio && ./run.sh  (status)"
ws_log_info "tmux:   USE_TMUX=1 ./linkkin-run.sh"

exit "$EXIT_OK"
