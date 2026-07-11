#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="backup-verify.sh"
WS_HELP_TITLE="backup-verify.sh — verify backup integrity"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./backup-verify.sh [backup-file] [-h|--help]

Verifies the latest (or given) backup archive / SQL dump:
  - file exists and size > 0
  - PostgreSQL dump header readable
  - optional restore dry-run (BACKUP_VERIFY_RESTORE=1)

Environment:
  DB_BACKUP_DIR   backup directory (default: db-dump)
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

BACKUP_FILE="${1:-}"
BACKUP_DIR="${DB_BACKUP_DIR:-$WORKSPACE_ROOT/db-dump}"
FAIL=0

check_ok() { ws_log_ok "$1"; }
check_fail() { ws_log_fail "$1"; FAIL=1; }

ws_header "Backup verification"

if [[ -n "$BACKUP_FILE" && "$BACKUP_FILE" != --* ]]; then
  TARGET="$BACKUP_FILE"
else
  TARGET="$(find "$BACKUP_DIR" -maxdepth 1 \( -name 'linkkin_backup_*.tar.gz' -o -name '*.sql' \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
  [[ -z "$TARGET" ]] && TARGET="$(ls -t "$BACKUP_DIR"/*.sql 2>/dev/null | head -1 || true)"
fi

if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  check_fail "No backup found in $BACKUP_DIR"
  exit "$EXIT_FAIL"
fi

check_ok "Backup exists: $TARGET"

size="$(stat -c '%s' "$TARGET" 2>/dev/null || stat -f '%z' "$TARGET" 2>/dev/null || echo 0)"
if [[ "$size" -gt 1024 ]]; then
  check_ok "File size valid ($(numfmt --to=iec "$size" 2>/dev/null || echo "${size} bytes"))"
else
  check_fail "File too small (${size} bytes)"
fi

# Resolve SQL dump path
SQL_FILE="$TARGET"
if [[ "$TARGET" == *.tar.gz ]]; then
  ws_log_info "Inspecting archive..."
  TMP_EXTRACT="$(mktemp -d)"
  tar -xzf "$TARGET" -C "$TMP_EXTRACT"
  SQL_FILE="$(find "$TMP_EXTRACT" -name '*.sql' -type f | head -1)"
  if [[ -n "$SQL_FILE" ]]; then
    check_ok "Archive contains SQL dump"
  else
    check_fail "Archive has no .sql dump"
    SQL_FILE=""
  fi
fi

if [[ -n "$SQL_FILE" && -f "$SQL_FILE" ]]; then
  if head -5 "$SQL_FILE" | grep -qiE 'PostgreSQL database dump|CREATE |COPY '; then
    check_ok "PostgreSQL dump readable"
  else
    check_fail "Dump does not look like PostgreSQL SQL"
  fi

  if [[ "${BACKUP_VERIFY_RESTORE:-0}" == "1" ]]; then
    ws_log_info "Restore test (temp DB)..."
    ENV_FILE="$(repo_dir linkkin-backend)/.env"
    [[ -f "$ENV_FILE" ]] || ENV_FILE="$WORKSPACE_ROOT/.env"
    DB_USER="$(read_env_var "$ENV_FILE" DB_USER || true)"; DB_USER="${DB_USER:-postgres}"
    DB_HOST="$(read_env_var "$ENV_FILE" DB_HOST || true)"; DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="$(read_env_var "$ENV_FILE" DB_PORT || true)"; DB_PORT="${DB_PORT:-5432}"
    DB_PASSWORD="$(read_env_var "$ENV_FILE" DB_PASSWORD || true)"
    TEST_DB="linkkin_backup_verify_$$"
    export PGPASSWORD="${DB_PASSWORD:-}"
    if dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" --if-exists "$TEST_DB" 2>/dev/null && \
       createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$TEST_DB" 2>/dev/null && \
       psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -v ON_ERROR_STOP=1 -f "$SQL_FILE" >/dev/null 2>&1; then
      check_ok "Restore test passed ($TEST_DB)"
      dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" --if-exists "$TEST_DB" 2>/dev/null || true
    else
      check_fail "Restore test failed"
      dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" --if-exists "$TEST_DB" 2>/dev/null || true
    fi
  else
    ws_log_info "Restore test skipped (set BACKUP_VERIFY_RESTORE=1 for full test)"
  fi
fi

[[ "$SQL_FILE" != "$TARGET" && -n "${TMP_EXTRACT:-}" ]] && rm -rf "$TMP_EXTRACT"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}✓ Backup verification passed${NC}"
  exit "$EXIT_OK"
fi
echo -e "${RED}✗ Backup verification failed${NC}"
exit "$EXIT_FAIL"
