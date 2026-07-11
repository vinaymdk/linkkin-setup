#!/usr/bin/env bash
# Check which backend migrations may not be applied (schema sentinel probes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="migration-check.sh"
WS_HELP_TITLE="migration-check.sh — pending migration check"
WS_HELP_BODY="Usage: ./migration-check.sh [--apply] [-h|--help]

Probes the database for expected schema artifacts.
Lists migrations that may not be applied yet.
Use --apply to run global.migrations.sh after confirmation."

# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

BACKEND_ROOT="$(repo_dir linkkin-backend)"

APPLY=0
for arg in "$@"; do
  [[ "$arg" == "--apply" ]] && APPLY=1
done

ENV_FILE="$(repo_dir linkkin-backend)/.env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$WORKSPACE_ROOT/.env"

DB_NAME="$(read_env_var "$ENV_FILE" DB_NAME || true)"; DB_NAME="${DB_NAME:-linkkin_db}"
DB_USER="$(read_env_var "$ENV_FILE" DB_USER || true)"; DB_USER="${DB_USER:-postgres}"
DB_HOST="$(read_env_var "$ENV_FILE" DB_HOST || true)"; DB_HOST="${DB_HOST:-localhost}"
DB_PORT="$(read_env_var "$ENV_FILE" DB_PORT || true)"; DB_PORT="${DB_PORT:-5432}"
DB_PASSWORD="$(read_env_var "$ENV_FILE" DB_PASSWORD || true)"

ws_header "Migration check"

if ! command -v psql >/dev/null 2>&1; then
  ws_log_fail "psql not installed"
  exit "$EXIT_CONFIG"
fi

if ! PGPASSWORD="${DB_PASSWORD:-}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
  ws_log_fail "Cannot connect to $DB_NAME@$DB_HOST"
  exit "$EXIT_FAIL"
fi
ws_log_ok "Database connected"

# migration_file|description|SQL probe (must return rows if applied)
read -r -d '' SENTINELS <<'EOF' || true
062_support_module.sql|support module|SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='support_articles' LIMIT 1
063_support_status_communities_calls.sql|support extensions|SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='support_faq' LIMIT 1
080_daily_contents.sql|daily contents|SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='daily_contents' LIMIT 1
081_daily_content_status.sql|daily content status column|SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='daily_contents' AND column_name='status' LIMIT 1
076_username_namespace.sql|username namespace|SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='username' LIMIT 1
052_razorpay_billing.sql|razorpay billing|SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='billing_orders' LIMIT 1
061_database_backups.sql|database backups|SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='database_backups' LIMIT 1
EOF

PENDING=()

while IFS='|' read -r file desc probe; do
  [[ -z "$file" ]] && continue
  if ! PGPASSWORD="${DB_PASSWORD:-}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "$probe" 2>/dev/null | grep -q 1; then
    PENDING+=("$file — $desc")
  fi
done <<< "$SENTINELS"

# Count migration files on disk
MIG_SCRIPT="$BACKEND_ROOT/scripts/global.migrations.sh"
if [[ -f "$MIG_SCRIPT" ]]; then
  total="$(grep -E '\.sql"' "$MIG_SCRIPT" | wc -l | xargs)"
  ws_log_info "Migration catalog: ~$total SQL files in global.migrations.sh"
fi

echo ""
if [[ ${#PENDING[@]} -eq 0 ]]; then
  ws_log_ok "No pending migrations detected (sentinel probes passed)"
  exit "$EXIT_OK"
fi

echo "Possibly pending migrations:"
for p in "${PENDING[@]}"; do
  echo "  - $p"
done
echo ""

if [[ "$APPLY" == "1" ]]; then
  if [[ "${MIGRATION_CONFIRM:-}" != "1" ]]; then
    read -r -p "Run global.migrations.sh now? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { ws_log_info "Aborted"; exit "$EXIT_BLOCKED"; }
  fi
  bash "$MIG_SCRIPT"
  ws_log_ok "Migrations applied"
  exit "$EXIT_OK"
fi

ws_log_warn "Run with --apply to migrate after review"
exit "$EXIT_BLOCKED"
