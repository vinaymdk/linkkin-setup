#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="bootstrap.sh"
WS_HELP_TITLE="bootstrap.sh — new machine onboarding"
WS_HELP_BODY="Usage: ./bootstrap.sh [-h|--help]

Clones missing repos, fixes permissions, runs setup + doctor."
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

CLONE_BASE="${CLONE_BASE:-$(ws_repos_parent)}"

ws_header "Bootstrap (clone + setup + doctor)"

if ! command -v git >/dev/null 2>&1; then
  ws_log_fail "git is required"
  exit "$EXIT_CONFIG"
fi

clone_missing() {
  local rel="$1"
  local name
  name="$(repo_basename "$rel")"
  local target="$CLONE_BASE/$name"

  if [[ "$rel" == linkkin-radio ]]; then
    ws_log_ok "linkkin-radio (included in linkkin-setup)"
    return 0
  fi

  if [[ -d "$target/.git" ]]; then
    ws_log_ok "$name already cloned"
    return 0
  fi

  local url
  url="$(ws_clone_url "$name")"
  ws_log_info "Cloning $url → $target"
  git clone "$url" "$target"
  ws_log_ok "$name cloned"
}

for entry in "${WORKSPACE_REPOS[@]}"; do
  rel="${entry#*:}"
  clone_missing "$rel"
done

"$ROOT/fix-permissions.sh"

ws_log_info "Running linkkin-setup.sh..."
"$ROOT/linkkin-setup.sh"

ws_log_info "Running linkkin-doctor.sh..."
"$ROOT/linkkin-doctor.sh" || true

ws_log_ok "Bootstrap complete"
echo ""
echo "  ./linkkin-run.sh     # start dev stack"
echo "  ./health.sh          # verify services"
exit "$EXIT_OK"
