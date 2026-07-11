#!/usr/bin/env bash
# Reusable CI pipeline — same scripts as local dev (Local == CI == Production).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"

PHASE="${1:-all}"
WS_SCRIPT_NAME="ci-pipeline.sh"
WS_HELP_TITLE="scripts/ci-pipeline.sh — CI/CD entry point"
WS_HELP_BODY="Usage: ./scripts/ci-pipeline.sh <phase>

Phases:
  doctor     Run linkkin-doctor.sh
  setup      Run linkkin-setup.sh (use npm ci in CI via SKIP_NPM_CI=0)
  test       Run unit tests in backend + web
  build      Build web, admin, support
  preflight  Run preflight.sh (git checks skipped)
  health     Run health.sh
  deploy     Run linkkin-backend/deploy.sh
  all        doctor → test → build → preflight

Exit codes: 0=ok, 1=fail, 2=blocked (preflight)"
ws_parse_args "$@"

run_doctor() {
  "$ROOT/linkkin-doctor.sh"
}

run_setup() {
  if [[ "${CI:-}" == "true" || "${USE_NPM_CI:-}" == "1" ]]; then
    for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support; do
      [[ -f "$(repo_dir "$dir")/package-lock.json" ]] && (cd "$(repo_dir "$dir")" && npm ci)
    done
  else
    "$ROOT/linkkin-setup.sh"
  fi
}

run_test() {
  for dir in linkkin-backend linkkin-web; do
    if [[ -f "$(repo_dir "$dir")/package.json" ]]; then
      (cd "$(repo_dir "$dir")" && LINKKIN_SKIP_PERFORMANCE_CONTRACT=1 npm test)
    fi
  done
}

run_build() {
  for dir in linkkin-web linkkin-admin linkkin-support; do
    if node -e "const p=require('$(repo_dir "$dir")/package.json'); process.exit(p.scripts?.build?0:1)" 2>/dev/null; then
      (cd "$(repo_dir "$dir")" && npm run build)
    fi
  done
}

run_preflight() {
  "$ROOT/secret-check.sh" || return 1
  SKIP_GIT_CLEAN=1 "$ROOT/preflight.sh" --skip-git
}

case "$PHASE" in
  doctor)    run_doctor ;;
  setup)     run_setup ;;
  test)      run_test ;;
  build)     run_build ;;
  preflight) run_preflight ;;
  health)    "$ROOT/health.sh" ;;
  deploy)    run_repo_script linkkin-backend deploy.sh ;;
  all)
    run_doctor
    run_test
    run_build
    run_preflight
    ;;
  -h|--help) ws_show_help ;;
  *)
    echo "Unknown phase: $PHASE" >&2
    exit "$EXIT_USAGE"
    ;;
esac
