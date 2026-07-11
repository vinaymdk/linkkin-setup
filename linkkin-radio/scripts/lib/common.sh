#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${LINKKIN_COMMON_LOADED:-}" ]]; then
  LINKKIN_COMMON_LOADED=1

  REPO_NAME="${LINKKIN_REPO_NAME:-linkkin-radio}"
  REPO_ROOT="${LINKKIN_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  SETUP_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
  BACKEND_ROOT="$(cd "$SETUP_ROOT/../linkkin-backend" 2>/dev/null && pwd || echo "$SETUP_ROOT/../linkkin-backend")"

  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
  DOCTOR_FAIL=0

  header() { echo ""; echo -e "${CYAN}=== $REPO_NAME — $1 ===${NC}"; echo ""; }
  log_ok()   { echo -e "${GREEN}✓${NC} $1"; }
  log_fail() { echo -e "${RED}✗${NC} $1"; DOCTOR_FAIL=1; }
  log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
  log_info() { echo -e "${BLUE}→${NC} $1"; }

  check_node() {
    if command -v node >/dev/null 2>&1; then log_ok "Node $(node -v)"; else log_fail "Node.js"; fi
  }
  check_npm() {
    if command -v npm >/dev/null 2>&1; then log_ok "npm $(npm -v)"; else log_fail "npm"; fi
  }
  copy_env_from_example() {
    if [[ -f "$REPO_ROOT/.env" ]]; then log_info ".env exists — skipped"; return; fi
    [[ -f "$REPO_ROOT/.env.example" ]] && cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env" && log_ok "Created .env"
  }
  doctor_summary() {
    echo ""
    [[ "$DOCTOR_FAIL" -eq 0 ]] && echo -e "${GREEN}✓ Build Ready${NC}" && return 0
    echo -e "${RED}✗ Issues found${NC}" && return 1
  }
fi
