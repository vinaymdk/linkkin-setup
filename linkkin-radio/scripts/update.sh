#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

header "Update"

if [[ "${GIT_PULL:-0}" == "1" ]] && git -C "$BACKEND_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$BACKEND_ROOT" pull --ff-only
  log_ok "linkkin-backend git pull"
fi

log_ok "Update complete — re-run doctor after nginx/icecast changes"
