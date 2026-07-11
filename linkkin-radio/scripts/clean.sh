#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

header "Clean"

log_info "No build artifacts in linkkin-radio — clearing local .env backups only"
rm -f "$REPO_ROOT/.env.bak" 2>/dev/null || true
log_ok "Clean complete"
