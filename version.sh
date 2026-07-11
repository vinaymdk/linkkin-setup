#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="version.sh"
WS_HELP_TITLE="version.sh — git branch, version, commit per repo"
WS_HELP_BODY="Usage: ./version.sh [-h|--help]"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

ws_header "Versions"

print_repo_version() {
  local label="$1" dir="$2"
  local info branch version commit tag
  info="$(git_repo_info "$dir")"
  IFS='|' read -r branch version commit tag <<< "$info"

  echo "$label"
  echo "  branch:  $branch"
  echo "  version: $version"
  echo "  commit:  $commit"
  [[ -n "$tag" ]] && echo "  tag:     $tag"
  echo "-------------"
}

foreach_repo print_repo_version
exit "$EXIT_OK"
