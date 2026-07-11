#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="linkkin-update.sh"
WS_HELP_TITLE="linkkin-update.sh — update all repositories"
WS_HELP_BODY="Usage: ./linkkin-update.sh [-h|--help]

Runs git pull (default) + ./update.sh per repo.
  GIT_PULL=0 ./linkkin-update.sh   # skip pull"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

GIT_PULL="${GIT_PULL:-1}"
export GIT_PULL

ws_header "Update (git pull + update.sh)"

FAILED=0

do_update() {
  local label="$1" dir="$2"
  local repo_path
  repo_path="$(repo_dir "$dir")"

  echo -e "${CYAN}--- $label ---${NC}"

  if [[ "$GIT_PULL" == "1" ]] && git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ws_log_info "git pull $dir"
    if git -C "$repo_path" pull --ff-only; then
      ws_log_ok "git pull"
    else
      ws_log_warn "git pull failed (continuing with update.sh)"
    fi
  fi

  if run_repo_script "$dir" "update.sh"; then
    ws_log_ok "$label update complete"
  else
    ws_log_fail "$label update failed"
    FAILED=1
  fi
  echo ""
}

foreach_repo do_update

if [[ "$FAILED" -eq 0 ]]; then
  ws_log_ok "All repositories updated"
else
  exit "$EXIT_FAIL"
fi

exit "$EXIT_OK"
