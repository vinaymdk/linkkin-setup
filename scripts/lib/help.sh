#!/usr/bin/env bash
# Standard exit codes and --help support for workspace scripts.

set -euo pipefail

if [[ -z "${LINKKIN_HELP_LOADED:-}" ]]; then
  LINKKIN_HELP_LOADED=1

  # Exit codes (consistent across all scripts)
  readonly EXIT_OK=0
  readonly EXIT_FAIL=1
  readonly EXIT_BLOCKED=2      # preflight / deployment blocked
  readonly EXIT_CONFIG=3       # missing config or dependency
  readonly EXIT_USAGE=64       # invalid arguments / --help

  ws_show_help() {
    local script="${WS_SCRIPT_NAME:-$0}"
    cat <<EOF
${WS_HELP_TITLE:-LinkKin workspace script}

${WS_HELP_BODY:-No help text defined.}

Exit codes:
  0   Success
  1   General failure
  2   Blocked (preflight / deployment)
  3   Configuration or dependency error
  64  Usage error (--help)

EOF
    exit "$EXIT_USAGE"
  }

  ws_parse_args() {
    for arg in "$@"; do
      case "$arg" in
        -h|--help) ws_show_help ;;
      esac
    done
  }
fi
