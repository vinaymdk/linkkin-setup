#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="secret-check.sh"
WS_HELP_TITLE="secret-check.sh — scan for committed secrets"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./secret-check.sh [--fix-ignore] [-h|--help]

Scans git repos for:
  - .env / credentials tracked in git
  - Firebase service account keys
  - Private keys, API secrets, live payment keys

Exit 1 if potential secrets found.
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

FOUND=0
FINDINGS=()

add_finding() {
  FINDINGS+=("$1")
  FOUND=1
}

ws_header "Secret scan"

# Patterns that suggest real secrets (not placeholders)
SECRET_PATTERNS=(
  'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
  'firebase.*private_key'
  '"private_key":\s*"-----'
  'rzp_live_[a-zA-Z0-9]+'
  'sk_live_[a-zA-Z0-9]+'
  'whsec_[a-zA-Z0-9]{20,}'
  'CLOUDINARY_URL=cloudinary://[^x@]+:[^@]+@'
  'FAST2SMS_API_KEY=[a-zA-Z0-9]{20,}'
  'RZP_KEY_SECRET=(?!your_|xxxx)'
)

# Files that must never be tracked
FORBIDDEN_TRACKED=(
  '.env'
  'firebase-service-account.json'
  '*.pem'
  '*.p12'
  'id_rsa'
  'id_ed25519'
)

scan_repo() {
  local label="$1" dir="$2"
  local path
  path="$(repo_dir "$dir")"
  git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  echo -e "${CYAN}--- $label ---${NC}"

  # Tracked forbidden paths
  local tracked
  tracked="$(git -C "$path" ls-files 2>/dev/null || true)"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      .env|.env.local|.env.production) add_finding "$dir: tracked $f" ;;
      firebase-service-account.json|*firebase*service*account*) add_finding "$dir: tracked $f" ;;
      *.pem|*.p12|*.key) add_finding "$dir: tracked sensitive file $f" ;;
    esac
  done <<< "$tracked"

  # History: .env ever committed?
  if git -C "$path" log --all --oneline -- ".env" ".env.local" 2>/dev/null | head -1 | grep -q .; then
    add_finding "$dir: .env found in git history (rotate secrets)"
  fi

  # Content scan on tracked files
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" == *.example ]] && continue
    [[ "$file" == *package-lock.json ]] && continue
    [[ "$file" == node_modules/* ]] && continue
    [[ "$file" == build/* ]] && continue
    [[ "$file" == .dart_tool/* ]] && continue
    [[ "$file" == dist/* ]] && continue
    [[ "$file" == *.dill ]] && continue
    [[ ! -f "$path/$file" ]] && continue
    for pattern in "${SECRET_PATTERNS[@]}"; do
      if grep -qE "$pattern" "$path/$file" 2>/dev/null; then
        add_finding "$dir: pattern in $file"
      fi
    done
  done <<< "$tracked"

  # Workspace-level backend firebase file (even if gitignored but present)
  if [[ "$dir" == "linkkin-backend" && -f "$path/firebase-service-account.json" ]]; then
    if git -C "$path" check-ignore -q firebase-service-account.json 2>/dev/null; then
      ws_log_ok "firebase-service-account.json gitignored"
    elif echo "$tracked" | grep -q firebase-service-account.json; then
      add_finding "linkkin-backend: firebase-service-account.json is tracked"
    fi
  fi
}

foreach_repo scan_repo

# Monorepo root .env
if [[ -f "$WORKSPACE_ROOT/.env" ]] && git -C "$WORKSPACE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$WORKSPACE_ROOT" ls-files --error-unmatch .env >/dev/null 2>&1; then
    add_finding "workspace root: .env is tracked"
  fi
fi

echo ""
if [[ "$FOUND" -eq 0 ]]; then
  ws_log_ok "No secrets detected"
  exit "$EXIT_OK"
fi

echo -e "${RED}✗ Possible secret(s) detected${NC}"
echo ""
for f in "${FINDINGS[@]}"; do
  echo "  - $f"
done
echo ""
ws_log_info "Rotate any exposed credentials and add paths to .gitignore"
exit "$EXIT_FAIL"
