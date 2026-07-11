#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="fix-permissions.sh"
WS_HELP_TITLE="fix-permissions.sh — chmod scripts and audit sensitive paths"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./fix-permissions.sh [--audit-only] [-h|--help]

Fixes:
  scripts/*.sh     755 (executable)
  .env files       600
  uploads/ logs/   755

--audit-only   Report issues without changing permissions.
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

AUDIT_ONLY=0
for arg in "$@"; do
  [[ "$arg" == "--audit-only" ]] && AUDIT_ONLY=1
done

ISSUES=0

apply_mode() {
  local path="$1" mode="$2"
  [[ -e "$path" ]] || return 0
  local current want
  current="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%OLp' "$path" 2>/dev/null || echo "")"
  want="$mode"
  if [[ "$current" == "$want" ]]; then
    return 0
  fi
  if [[ "$AUDIT_ONLY" == "1" ]]; then
    ws_log_warn "$path permissions $current (expected $want)"
    ISSUES=1
  else
    chmod "$mode" "$path"
    ws_log_ok "$path → $mode"
  fi
}

apply_dir_mode() {
  local path="$1" mode="$2"
  [[ -d "$path" ]] || return 0
  apply_mode "$path" "$mode"
}

ws_header "Permissions"

if [[ "$AUDIT_ONLY" == "1" ]]; then
  ws_log_info "Audit only (no changes)"
else
  ws_log_info "Fixing permissions"
fi

# Workspace scripts
chmod +x "$ROOT"/*.sh 2>/dev/null || true
chmod +x "$ROOT"/scripts/*.sh 2>/dev/null || true
chmod +x "$ROOT"/scripts/lib/*.sh 2>/dev/null || true

fix_repo_perms() {
  local _label="$1" dir="$2"
  local path
  path="$(repo_dir "$dir")"
  chmod +x "$path"/*.sh 2>/dev/null || true
  chmod +x "$path"/scripts/*.sh 2>/dev/null || true
  chmod +x "$path"/scripts/lib/*.sh 2>/dev/null || true

  apply_mode "$path/.env" 600
  apply_dir_mode "$path/uploads" 755
  apply_dir_mode "$path/logs" 755
}

foreach_repo fix_repo_perms

apply_mode "$WORKSPACE_ROOT/.env" 600
apply_mode "$(repo_dir linkkin-mobile)/assets/env_defaults.env" 600

if [[ "$AUDIT_ONLY" == "1" && "$ISSUES" -eq 0 ]]; then
  ws_log_ok "Permission audit passed"
elif [[ "$AUDIT_ONLY" == "1" ]]; then
  ws_log_fail "Permission audit found issues"
  exit "$EXIT_FAIL"
else
  ws_log_ok "Permissions updated"
fi

exit "$EXIT_OK"
