#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="preflight.sh"
WS_HELP_TITLE="preflight.sh — pre-deployment validation"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./preflight.sh [options]

Validates the workspace before deployment. Exits 2 if deployment is blocked.

Options:
  --skip-git        Skip git clean / sync checks
  --skip-build      Skip build tests
  --skip-tests      Skip unit tests
  --skip-lint       Skip lint checks
  -h, --help        Show this help

Environment:
  SKIP_GIT_CLEAN=1  Same as --skip-git
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

SKIP_GIT=0 SKIP_BUILD=0 SKIP_TESTS=0 SKIP_LINT=0
for arg in "$@"; do
  case "$arg" in
    --skip-git)   SKIP_GIT=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --skip-lint)  SKIP_LINT=1 ;;
  esac
done
[[ "${SKIP_GIT_CLEAN:-0}" == "1" ]] && SKIP_GIT=1

BLOCKED=0
REASONS=()

pf_ok()   { ws_log_ok "$1"; }
pf_fail() { ws_log_fail "$1"; BLOCKED=1; REASONS+=("$1"); }
pf_warn() { ws_log_warn "$1"; }

ws_header "Preflight"

# --- Git ---
if [[ "$SKIP_GIT" != "1" ]]; then
  ws_log_info "Git checks"
  check_git_repo() {
    local label="$1" dir="$2"
    local path branch local_ref remote_ref
    path="$(repo_dir "$dir")"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD)"
    pf_ok "$label branch: $branch"

    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
      pf_fail "$label: working tree not clean"
    else
      pf_ok "$label: clean working tree"
    fi

    if git -C "$path" remote get-url origin >/dev/null 2>&1; then
      git -C "$path" fetch origin --quiet 2>/dev/null || pf_warn "$label: git fetch failed (offline?)"
      local_ref="$(git -C "$path" rev-parse HEAD 2>/dev/null)"
      remote_ref="$(git -C "$path" rev-parse "@{upstream}" 2>/dev/null || echo "")"
      if [[ -n "$remote_ref" && "$local_ref" != "$remote_ref" ]]; then
        pf_fail "$label: not synced with remote ($branch)"
      else
        pf_ok "$label: synced with remote"
      fi
    fi
  }
  foreach_repo check_git_repo
fi

# --- .env ---
ws_log_info "Environment files"
backend_env="$(repo_dir linkkin-backend)/.env"
if [[ -f "$backend_env" ]]; then
  pf_ok "Backend .env"
else
  pf_fail "Backend .env missing"
fi

if ./env-check.sh >/dev/null 2>&1; then
  pf_ok "env-check (no critical missing keys)"
else
  pf_warn "env-check reported differences (review ./env-check.sh)"
fi

# --- Disk / Memory ---
ws_log_info "Resources"
if command -v df >/dev/null 2>&1; then
  free_pct="$(df "$WORKSPACE_ROOT" | awk 'NR==2 {print 100-$5}')"
  if [[ "${free_pct:-0}" -ge "$PREFLIGHT_MIN_DISK_FREE" ]]; then
    pf_ok "Disk free: ${free_pct}%"
  else
    pf_fail "Disk low: only ${free_pct}% free (need >= ${PREFLIGHT_MIN_DISK_FREE}%)"
  fi
fi
if command -v free >/dev/null 2>&1; then
  avail_mb="$(free -m | awk '/^Mem:/ {print $7}')"
  if [[ "${avail_mb:-0}" -ge "$PREFLIGHT_MIN_MEMORY_MB" ]]; then
    pf_ok "Memory available: ${avail_mb}MB"
  else
    pf_fail "Low memory: ${avail_mb}MB available (need >= ${PREFLIGHT_MIN_MEMORY_MB}MB)"
  fi
fi

# --- DB / Redis ---
ws_log_info "Services"
if [[ -f "$backend_env" ]]; then
  DB_PASSWORD="$(read_env_var "$backend_env" DB_PASSWORD || true)"
  DB_NAME="$(read_env_var "$backend_env" DB_NAME || true)"
  DB_USER="$(read_env_var "$backend_env" DB_USER || true)"
  DB_HOST="$(read_env_var "$backend_env" DB_HOST || true)"
  DB_PORT="$(read_env_var "$backend_env" DB_PORT || true)"
  DB_NAME="${DB_NAME:-linkkin_db}"; DB_USER="${DB_USER:-postgres}"
  DB_HOST="${DB_HOST:-localhost}"; DB_PORT="${DB_PORT:-5432}"
  if command -v psql >/dev/null 2>&1 && \
     PGPASSWORD="${DB_PASSWORD:-}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
    pf_ok "Database connectivity"
  else
    pf_fail "Database connectivity"
  fi
fi
if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
  pf_ok "Redis"
else
  pf_warn "Redis (optional — not running)"
fi

# --- Doctor ---
ws_log_info "Doctor"
if ./linkkin-doctor.sh >/dev/null 2>&1; then
  pf_ok "linkkin-doctor"
else
  pf_warn "linkkin-doctor reported issues"
fi

# --- Build ---
if [[ "$SKIP_BUILD" != "1" ]]; then
  ws_log_info "Build tests"
  for dir in linkkin-web linkkin-admin linkkin-support; do
    if [[ -f "$(repo_dir "$dir")/package.json" ]] && \
       node -e "const p=require('$(repo_dir "$dir")/package.json'); process.exit(p.scripts?.build?0:1)" 2>/dev/null; then
      if (cd "$(repo_dir "$dir")" && npm run build >/dev/null 2>&1); then
        pf_ok "$dir build"
      else
        pf_fail "$dir build failed"
      fi
    fi
  done
fi

# --- Tests ---
if [[ "$SKIP_TESTS" != "1" ]]; then
  ws_log_info "Unit tests"
  for dir in linkkin-backend linkkin-web; do
    if [[ -f "$(repo_dir "$dir")/package.json" ]] && \
       node -e "const p=require('$(repo_dir "$dir")/package.json'); process.exit(p.scripts?.test?0:1)" 2>/dev/null; then
      if (cd "$(repo_dir "$dir")" && LINKKIN_SKIP_PERFORMANCE_CONTRACT=1 npm test >/dev/null 2>&1); then
        pf_ok "$dir tests"
      else
        pf_fail "$dir tests failed"
      fi
    fi
  done
fi

# --- Lint ---
if [[ "$SKIP_LINT" != "1" ]]; then
  ws_log_info "Lint"
  for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support; do
    if [[ -f "$(repo_dir "$dir")/package.json" ]] && \
       node -e "const p=require('$(repo_dir "$dir")/package.json'); process.exit(p.scripts?.lint?0:1)" 2>/dev/null; then
      if (cd "$(repo_dir "$dir")" && npm run lint >/dev/null 2>&1); then
        pf_ok "$dir lint"
      else
        pf_fail "$dir lint failed"
      fi
    else
      pf_warn "$dir: no lint script (skipped)"
    fi
  done
fi

# --- Version consistency ---
ws_log_info "Version consistency"
versions=()
for entry in "${WORKSPACE_REPOS[@]}"; do
  dir="${entry#*:}"
  info="$(git_repo_info "$dir")"
  ver="${info#*|}"; ver="${ver%%|*}"
  [[ "$ver" != "—" ]] && versions+=("$ver")
done
if [[ ${#versions[@]} -gt 0 ]]; then
  first="${versions[0]}"
  consistent=1
  for v in "${versions[@]}"; do
    [[ "$v" == "$first" ]] || consistent=0
  done
  if [[ "$consistent" == "1" ]]; then
    pf_ok "Package versions aligned ($first)"
  else
    pf_warn "Package versions differ across repos: ${versions[*]}"
  fi
fi

echo ""
if [[ "$BLOCKED" -eq 0 ]]; then
  echo -e "${GREEN}✓ Ready for Deployment${NC}"
  exit "$EXIT_OK"
fi

echo -e "${RED}✗ Deployment Blocked${NC}"
echo ""
echo "Reasons:"
for r in "${REASONS[@]}"; do
  echo "  - $r"
done
exit "$EXIT_BLOCKED"
