#!/usr/bin/env bash
set -euo pipefail

LINKKIN_REPO_NAME="linkkin-radio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKKIN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

header "Status"

if [[ -f "$REPO_ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$REPO_ROOT/.env"; set +a
fi

echo "Icecast admin:  ${ICECAST_ADMIN_URL:-http://127.0.0.1:8010}"
echo "Public URL:     ${ICECAST_PUBLIC_URL:-https://radio.linkkin.chat}"
echo "Gateway port:   ${BROADCAST_GATEWAY_PUBLIC_PORT:-2001}"
echo ""

systemctl status icecast2 --no-pager 2>/dev/null | head -5 || true
systemctl status nginx --no-pager 2>/dev/null | head -5 || true
