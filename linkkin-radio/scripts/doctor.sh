#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

header "Doctor"

check_node || true
check_npm || true

[[ -f "$REPO_ROOT/.env" ]] && log_ok ".env" || log_fail ".env"

for cmd in icecast2 nginx ffmpeg; do
  command -v "$cmd" >/dev/null 2>&1 && log_ok "$cmd" || log_warn "$cmd (install via server-setup.sh)"
done

if systemctl is-active icecast2 >/dev/null 2>&1; then log_ok "Icecast service"; else log_warn "Icecast service (not running)"; fi
if systemctl is-active nginx >/dev/null 2>&1; then log_ok "Nginx"; else log_warn "Nginx (not running)"; fi

if command -v ss >/dev/null 2>&1; then
  for port in 8010 8011 8089; do
    ss -tln | grep -q ":${port} " && log_ok "Port $port listening" || log_warn "Port $port (not listening)"
  done
fi

doctor_summary
