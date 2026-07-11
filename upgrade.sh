#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="upgrade.sh"
WS_HELP_TITLE="upgrade.sh — upgrade toolchain and dependencies"
WS_HELP_BODY="Usage: ./upgrade.sh [--skip-toolchain] [-h|--help]

Upgrades Node (via nvm hint), Flutter, npm packages, and runs audits."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

SKIP_TOOLCHAIN=0
for arg in "$@"; do
  [[ "$arg" == "--skip-toolchain" ]] && SKIP_TOOLCHAIN=1
done

ws_header "Workspace upgrade"

if [[ "$SKIP_TOOLCHAIN" != "1" ]]; then
  ws_log_info "Toolchain"
  if command -v node >/dev/null 2>&1; then
    ws_log_ok "Node $(node -v) — upgrade via nvm/fnm or nodesource if needed"
  fi
  if command -v flutter >/dev/null 2>&1; then
    ws_log_info "flutter upgrade..."
    flutter upgrade || ws_log_warn "flutter upgrade failed"
    ws_log_ok "Flutter $(flutter --version 2>/dev/null | head -1)"
  fi
fi

ws_log_info "npm update (node repos)"
for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support; do
  if [[ -f "$(repo_dir "$dir")/package.json" ]]; then
    echo -e "${CYAN}--- $dir ---${NC}"
    (cd "$(repo_dir "$dir")" && npm update) || ws_log_warn "$dir npm update had issues"
    (cd "$(repo_dir "$dir")" && npm audit) || true
  fi
done

if [[ -f "$(repo_dir linkkin-mobile)/pubspec.yaml" ]] && command -v flutter >/dev/null 2>&1; then
  ws_log_info "Flutter pub upgrade"
  (cd "$(repo_dir linkkin-mobile)" && flutter pub upgrade) || ws_log_warn "pub upgrade failed"
fi

ws_log_ok "Upgrade complete — run ./linkkin-update.sh to sync lockfiles"
exit "$EXIT_OK"
