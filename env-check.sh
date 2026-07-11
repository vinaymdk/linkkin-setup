#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="env-check.sh"
WS_HELP_TITLE="env-check.sh — compare .env.example vs .env"
WS_HELP_BODY="Usage: ./env-check.sh [-h|--help]

Reports missing and extra keys per repository."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

extract_env_keys() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$file" 2>/dev/null \
    | cut -d= -f1 \
    | sort -u
}

compare_env_files() {
  local label="$1" dir="$2"
  local root example env_file
  root="$(repo_dir "$dir")"
  example="$root/.env.example"
  env_file="$root/.env"

  # Mobile uses assets/env_defaults.env
  if [[ "$dir" == "linkkin-mobile" ]]; then
    example="$root/.env.example"
    env_file="$root/assets/env_defaults.env"
  fi

  if [[ ! -f "$example" ]]; then
    ws_log_warn "$label — no .env.example (skipped)"
    return 0
  fi

  echo -e "${CYAN}--- $label ---${NC}"

  if [[ ! -f "$env_file" ]]; then
    ws_log_fail "$env_file missing"
    echo ""
    return 1
  fi

  local missing extra
  missing="$(comm -23 <(extract_env_keys "$example") <(extract_env_keys "$env_file") || true)"
  extra="$(comm -13 <(extract_env_keys "$example") <(extract_env_keys "$env_file") || true)"

  if [[ -n "$missing" ]]; then
    echo "Missing (in .env.example but not in .env):"
    echo "$missing" | sed 's/^/  /'
  else
    echo "Missing: (none)"
  fi

  if [[ -n "$extra" ]]; then
    echo "Extra (in .env but not in .env.example):"
    echo "$extra" | sed 's/^/  /'
  else
    echo "Extra: (none)"
  fi
  echo ""
}

ws_header "Environment diff (.env.example vs .env)"

FAILED=0
do_env_check() {
  compare_env_files "$1" "$2" || FAILED=1
}
foreach_repo do_env_check

if [[ "$FAILED" -eq 0 ]]; then
  ws_log_ok "Environment check complete"
else
  exit "$EXIT_FAIL"
fi

exit "$EXIT_OK"
