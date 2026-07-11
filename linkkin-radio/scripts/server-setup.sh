#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

INSTALLER="$BACKEND_ROOT/scripts/radio.setup.install.sh"

header "Production radio server setup"

if [[ "$EUID" -ne 0 ]]; then
  log_fail "Run with sudo: sudo ./server-setup.sh"
  exit 1
fi

if [[ ! -f "$INSTALLER" ]]; then
  log_fail "Installer not found: $INSTALLER"
  exit 1
fi

log_info "Running $INSTALLER ..."
bash "$INSTALLER"
log_ok "Radio server setup complete"
