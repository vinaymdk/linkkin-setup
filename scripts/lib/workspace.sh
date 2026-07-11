#!/usr/bin/env bash
# Shared helpers for LinkKin workspace-level scripts.

set -euo pipefail

if [[ -z "${LINKKIN_WORKSPACE_LOADED:-}" ]]; then
  LINKKIN_WORKSPACE_LOADED=1

  WORKSPACE_ROOT="${LINKKIN_WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

  # shellcheck source=config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
  # shellcheck source=help.sh
  source "$(dirname "${BASH_SOURCE[0]}")/help.sh"

  ws_load_config || {
    # Fallback if workspace.yml missing
    WORKSPACE_REPOS=(
      "Backend:../linkkin-backend"
      "Web:../linkkin-web"
      "Admin:../linkkin-admin"
      "Support:../linkkin-support"
      "Mobile:../linkkin-mobile"
      "Radio:linkkin-radio"
    )
    PORT_BACKEND=8000 PORT_WEB=5173 PORT_ADMIN=5174 PORT_SUPPORT=5175 PORT_ICECAST=8089
    URL_BACKEND="http://127.0.0.1:8000" URL_WEB="http://127.0.0.1:5173"
    URL_ADMIN="http://127.0.0.1:5174" URL_SUPPORT="http://127.0.0.1:5175"
    URL_ICECAST="http://127.0.0.1:8089"
    WS_RUN_DIR=".linkkin-run" WS_GIT_ORG="vinaymdk"
    PREFLIGHT_MIN_DISK_FREE=10 PREFLIGHT_MIN_MEMORY_MB=512
  }

  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'

  ws_header() {
    echo ""
    echo -e "${CYAN}=== LinkKin Workspace — $1 ===${NC}"
    echo ""
  }

  ws_log_ok()   { echo -e "${GREEN}✓${NC} $1"; }
  ws_log_fail() { echo -e "${RED}✗${NC} $1"; }
  ws_log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
  ws_log_info() { echo -e "${BLUE}→${NC} $1"; }

  ws_repos_parent() {
    echo "$(cd "$WORKSPACE_ROOT/${WS_REPOS_PARENT:-..}" && pwd)"
  }

  repo_dir() {
    local p="$1"
    if [[ "$p" == linkkin-radio ]]; then
      echo "$(cd "$WORKSPACE_ROOT/linkkin-radio" && pwd)"
      return
    fi
    if [[ "$p" != */* ]]; then
      p="${WS_REPOS_PARENT:-..}/$p"
    fi
    echo "$(cd "$WORKSPACE_ROOT/$p" && pwd)"
  }

  repo_basename() {
    local p="$1"
    echo "${p##*/}"
  }

  repo_exists() {
    [[ -d "$(repo_dir "$1")" ]]
  }

  foreach_repo() {
    local callback="$1"
    local entry name dir
    for entry in "${WORKSPACE_REPOS[@]}"; do
      name="${entry%%:*}"
      dir="${entry#*:}"
      if repo_exists "$dir"; then
        "$callback" "$name" "$dir"
      else
        ws_log_warn "$name ($dir not found — skipped)"
      fi
    done
  }

  run_repo_script() {
    local dir="$1"
    local script="$2"
    shift 2
    local path
    path="$(repo_dir "$dir")/$script"
    if [[ -x "$path" ]]; then
      (cd "$(repo_dir "$dir")" && bash "./$script" "$@")
      return $?
    fi
    if [[ -f "$path" ]]; then
      (cd "$(repo_dir "$dir")" && bash "./$script" "$@")
      return $?
    fi
    ws_log_fail "$dir/$script not found"
    return 1
  }

  read_env_var() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 1
    grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*$//' | sed 's/^["'\'']//;s/["'\'']$//' | tr -d '\r' | xargs
  }

  git_repo_info() {
    local dir="$1"
    local root branch commit tag version
    root="$(repo_dir "$dir")"
    if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "—|—|—|—"
      return
    fi
    branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "—")"
    commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo "—")"
    tag="$(git -C "$root" describe --tags --exact-match 2>/dev/null || true)"
    version="—"
    if [[ -f "$root/package.json" ]]; then
      version="$(node -e "console.log(require('$root/package.json').version||'—')" 2>/dev/null || echo "—")"
    elif [[ -f "$root/pubspec.yaml" ]]; then
      version="$(grep -E '^version:' "$root/pubspec.yaml" | head -1 | awk '{print $2}' || echo "—")"
    fi
    echo "$branch|$version|$commit|${tag:-}"
  }

  pad_status_line() {
    local label="$1"
    local status="$2"
    printf "%-16s %s\n" "$label" "$status"
  }

  ws_pid_file() {
    echo "$(ws_run_dir)/pids.env"
  }

  ws_read_pid() {
    local var="$1"
    local pf
    pf="$(ws_pid_file)"
    [[ -f "$pf" ]] || return 1
    # shellcheck disable=SC1090
    source "$pf"
    echo "${!var:-}"
  }

  ws_service_running() {
    local pid
    pid="$(ws_read_pid "$1" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
  }
fi
