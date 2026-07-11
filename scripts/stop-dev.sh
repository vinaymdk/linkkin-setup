#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$ROOT/.linkkin-run"
PID_FILE="$RUN_DIR/pids.env"

if [[ -f "$PID_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PID_FILE"
  for key in PID_BACKEND PID_WEB PID_ADMIN PID_SUPPORT; do
    pid="${!key:-}"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null && echo "Stopped $key ($pid)" || true
  done
  rm -f "$PID_FILE" "$RUN_DIR"/*.pid
fi

if tmux has-session -t linkkin-dev 2>/dev/null; then
  tmux kill-session -t linkkin-dev
  echo "Stopped tmux session linkkin-dev"
fi

echo "Done."
