#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="rollback.sh"
WS_HELP_TITLE="rollback.sh — rollback to a tagged release"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./rollback.sh <tag> [options]

Example: ./rollback.sh v1.1.0

Flow:
  1. Stop dev/PM2 services
  2. Checkout tag in each git repo
  3. npm install (backend + frontends)
  4. Optional DB restore from releases/<tag>/ dump
  5. Restart PM2 + health check

Options:
  --db-dump PATH   Restore database from SQL dump before restart
  --no-restart     Checkout only (no PM2 restart)
  -y               Skip confirmation
  -h, --help       Show this help
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

TAG="${1:-}"
[[ -z "$TAG" || "$TAG" == --* ]] && { echo "Usage: ./rollback.sh v1.1.0" >&2; exit "$EXIT_USAGE"; }
shift || true

DB_DUMP=""
NO_RESTART=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-dump) DB_DUMP="${2:-}"; shift 2 ;;
    --no-restart) NO_RESTART=1; shift ;;
    -y) ASSUME_YES=1; shift ;;
    *) shift ;;
  esac
done
TAG="${TAG#v}"; TAG="v${TAG}"

PM2_APP_NAME="${PM2_APP_NAME:-linkkin-backend}"

ws_header "Rollback to $TAG"

if [[ "$ASSUME_YES" != "1" && "${ROLLBACK_CONFIRM:-}" != "1" ]]; then
  echo "This will checkout $TAG in all repos and restart services."
  read -r -p "Continue rollback? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { ws_log_info "Aborted"; exit "$EXIT_BLOCKED"; }
fi

# 1. Stop services
ws_log_info "Stopping services"
"$ROOT/scripts/stop-dev.sh" 2>/dev/null || true
if command -v pm2 >/dev/null 2>&1; then
  pm2 stop "$PM2_APP_NAME" 2>/dev/null || true
fi
ws_log_ok "Services stopped"

# 2. Checkout tag
ws_log_info "Checking out $TAG"
for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support linkkin-mobile; do
  path="$(repo_dir "$dir")"
  [[ -d "$path/.git" ]] || continue
  if git -C "$path" rev-parse "$TAG" >/dev/null 2>&1; then
    git -C "$path" checkout "$TAG"
    ws_log_ok "$dir → $TAG"
  else
    ws_log_warn "$dir: tag $TAG not found (skipped)"
  fi
done

# 3. Install dependencies
ws_log_info "Installing dependencies"
for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support; do
  [[ -f "$(repo_dir "$dir")/package.json" ]] || continue
  (cd "$(repo_dir "$dir")" && npm install) || ws_log_warn "$dir npm install failed"
done

# 4. Optional DB restore
dump_path="$DB_DUMP"
if [[ -z "$dump_path" && -f "$ROOT/releases/${TAG}/linkkin_db_${TAG}.sql" ]]; then
  dump_path="$ROOT/releases/${TAG}/linkkin_db_${TAG}.sql"
fi
if [[ -n "$dump_path" && -f "$dump_path" ]]; then
  ws_log_info "Restoring database from $dump_path"
  bash "$(repo_dir linkkin-backend)/scripts/restore-full-db.sh" "$dump_path" || ws_log_fail "DB restore failed"
else
  ws_log_info "No DB dump specified — schema unchanged"
  ws_log_info "Run: ./migration-check.sh --apply if needed"
fi

# 5. Restart + health
if [[ "$NO_RESTART" != "1" ]]; then
  if command -v pm2 >/dev/null 2>&1; then
    ws_log_info "Starting PM2 $PM2_APP_NAME"
    cd "$(repo_dir linkkin-backend)"
    pm2 start npm --name "$PM2_APP_NAME" -- start 2>/dev/null || pm2 restart "$PM2_APP_NAME"
    pm2 save 2>/dev/null || true
    ws_log_ok "PM2 restarted"
  else
    ws_log_warn "PM2 not found — start manually: cd linkkin-backend && ./run.sh"
  fi
fi

ws_log_info "Health check"
if "$ROOT/health.sh"; then
  ws_log_ok "Rollback to $TAG complete"
  exit "$EXIT_OK"
else
  ws_log_warn "Health check reported issues — verify manually"
  exit "$EXIT_FAIL"
fi
