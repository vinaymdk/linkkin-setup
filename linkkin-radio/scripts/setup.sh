#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

header "First-time setup"

check_node || true
check_npm || true
copy_env_from_example

if [[ -f "$BACKEND_ROOT/.env.example" ]]; then
  log_ok "Backend radio config template (linkkin-backend/.env.example)"
else
  log_warn "linkkin-backend not found at $BACKEND_ROOT"
fi

INSTALLER="$BACKEND_ROOT/scripts/radio.setup.install.sh"
if [[ -f "$INSTALLER" ]]; then
  log_info "Full stack install on production: sudo $INSTALLER"
  log_ok "Radio installer available"
else
  log_warn "radio.setup.install.sh not found"
fi

log_ok "Setup complete"
