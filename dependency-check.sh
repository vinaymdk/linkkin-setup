#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="dependency-check.sh"
WS_HELP_TITLE="dependency-check.sh — lock file integrity"
WS_HELP_BODY="Usage: ./dependency-check.sh [-h|--help]

Verifies package-lock.json / pubspec.lock exist, are committed, and match package manifests."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

FAIL=0

check_ok() { ws_log_ok "$1"; }
check_fail() { ws_log_fail "$1"; FAIL=1; }
check_warn() { ws_log_warn "$1"; }

ws_header "Dependency lock check"

check_node_lock() {
  local label="$1" dir="$2"
  local path lock pkg
  path="$(repo_dir "$dir")"
  lock="$path/package-lock.json"
  pkg="$path/package.json"

  [[ -f "$pkg" ]] || return 0

  echo -e "${CYAN}--- $label ---${NC}"

  if [[ -f "$lock" ]]; then
    check_ok "package-lock.json exists"
  else
    check_fail "package-lock.json missing"
    return
  fi

  if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$path" ls-files --error-unmatch package-lock.json >/dev/null 2>&1; then
      check_ok "package-lock.json committed"
    else
      check_fail "package-lock.json not tracked in git"
    fi

    if [[ -n "$(git -C "$path" status --porcelain package-lock.json package.json 2>/dev/null)" ]]; then
      check_warn "package.json or package-lock.json has uncommitted changes"
    else
      check_ok "no unexpected lockfile changes"
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    if (cd "$path" && npm ci --dry-run >/dev/null 2>&1); then
      check_ok "npm ci dry-run OK"
    else
      check_warn "npm ci dry-run failed (lock may be out of sync)"
    fi
  fi
}

check_flutter_lock() {
  local path lock
  path="$(repo_dir linkkin-mobile)"
  lock="$path/pubspec.lock"
  [[ -f "$path/pubspec.yaml" ]] || return 0

  echo -e "${CYAN}--- Mobile ---${NC}"

  if [[ -f "$lock" ]]; then
    check_ok "pubspec.lock exists"
  else
    check_fail "pubspec.lock missing"
    return
  fi

  if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$path" ls-files --error-unmatch pubspec.lock >/dev/null 2>&1; then
      check_ok "pubspec.lock committed"
    else
      check_fail "pubspec.lock not tracked in git"
    fi

    if [[ -n "$(git -C "$path" status --porcelain pubspec.lock pubspec.yaml 2>/dev/null)" ]]; then
      check_warn "pubspec.yaml or pubspec.lock has uncommitted changes"
    else
      check_ok "no unexpected pubspec changes"
    fi
  fi
}

check_node_lock "Backend" linkkin-backend
check_node_lock "Web" linkkin-web
check_node_lock "Admin" linkkin-admin
check_node_lock "Support" linkkin-support
check_flutter_lock

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}✓ Lock files OK${NC}"
  exit "$EXIT_OK"
fi
echo -e "${RED}✗ Lock file issues found${NC}"
exit "$EXIT_FAIL"
