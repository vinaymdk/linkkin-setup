#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SCRIPT_NAME="release.sh"
WS_HELP_TITLE="release.sh — version bump, tag, changelog, archive"
WS_HELP_BODY="$(cat <<'EOF'
Usage: ./release.sh <version> [options]

Example: ./release.sh 1.2.0

Steps:
  1. Bump package.json / pubspec.yaml versions
  2. Generate CHANGELOG.md per git repo
  3. Git commit + tag (vX.Y.Z) in each repo
  4. Push tags (set PUSH_TAGS=1)
  5. Archive build artifacts to releases/

Options:
  --no-tag      Skip git tag/commit
  --no-push     Skip git push
  --no-archive  Skip artifact archive
  -y            Skip confirmation prompt
  -h, --help    Show this help

Validation (before release):
  git clean, tests, preflight, secret-check, semver version
  Skip: SKIP_RELEASE_TESTS=1 SKIP_RELEASE_PREFLIGHT=1 RELEASE_CONFIRM=1
EOF
)"
# shellcheck source=scripts/lib/workspace.sh
source "$ROOT/scripts/lib/workspace.sh"
ws_parse_args "$@"

VERSION="${1:-}"
NO_TAG=0 NO_PUSH=0 NO_ARCHIVE=0 ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --no-tag)     NO_TAG=1 ;;
    --no-push)    NO_PUSH=1 ;;
    --no-archive) NO_ARCHIVE=1 ;;
    -y)           ASSUME_YES=1; RELEASE_CONFIRM=1 ;;
  esac
done

if [[ -z "$VERSION" || "$VERSION" == --* ]]; then
  echo "Usage: ./release.sh <version> (e.g. 1.2.0)" >&2
  exit "$EXIT_USAGE"
fi

VERSION="${VERSION#v}"
TAG="v${VERSION}"
RELEASE_DIR="$ROOT/releases/${TAG}"

validate_version() {
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    ws_log_fail "Invalid version '$VERSION' (use semver: 1.2.0)"
    exit "$EXIT_USAGE"
  fi
  ws_log_ok "Version format valid: $VERSION"
}

run_release_gates() {
  ws_log_info "Release validation"
  local gate_fail=0

  check_repo_clean() {
    local label="$1" dir="$2"
    local path
    path="$(repo_dir "$dir")"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
      ws_log_fail "$label: git working tree not clean"
      gate_fail=1
    else
      ws_log_ok "$label: git clean"
    fi
  }
  foreach_repo check_repo_clean

  if SKIP_RELEASE_TESTS=1; then
    ws_log_warn "Tests skipped (SKIP_RELEASE_TESTS=1)"
  else
    for dir in linkkin-backend linkkin-web; do
      if [[ -f "$(repo_dir "$dir")/package.json" ]] && \
         node -e "const p=require('$(repo_dir "$dir")/package.json'); process.exit(p.scripts?.test?0:1)" 2>/dev/null; then
        if (cd "$(repo_dir "$dir")" && LINKKIN_SKIP_PERFORMANCE_CONTRACT=1 npm test >/dev/null 2>&1); then
          ws_log_ok "$dir tests passed"
        else
          ws_log_fail "$dir tests failed"
          gate_fail=1
        fi
      fi
    done
  fi

  if SKIP_RELEASE_PREFLIGHT=1; then
    ws_log_warn "Preflight skipped (SKIP_RELEASE_PREFLIGHT=1)"
  elif ! SKIP_GIT_CLEAN=1 "$ROOT/preflight.sh" --skip-git --skip-build --skip-lint 2>/dev/null; then
    ws_log_fail "Preflight failed"
    gate_fail=1
  else
    ws_log_ok "Preflight passed"
  fi

  if ! "$ROOT/secret-check.sh" >/dev/null 2>&1; then
    ws_log_fail "secret-check failed — resolve before release"
    gate_fail=1
  else
    ws_log_ok "secret-check passed"
  fi

  [[ "$gate_fail" -eq 0 ]] || {
    ws_log_fail "Release gates failed — fix issues or use SKIP_RELEASE_* env vars"
    exit "$EXIT_BLOCKED"
  }
}

ws_header "Release $TAG"

validate_version
run_release_gates

if [[ "${RELEASE_CONFIRM:-}" != "1" && "$NO_TAG" != "1" && "$ASSUME_YES" != "1" ]]; then
  echo ""
  read -r -p "Continue release $TAG? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { ws_log_info "Release aborted"; exit "$EXIT_BLOCKED"; }
fi

bump_node() {
  local dir="$1"
  [[ -f "$(repo_dir "$dir")/package.json" ]] || return 0
  node -e "
    const fs=require('fs');
    const p='$(repo_dir "$dir")/package.json';
    const j=JSON.parse(fs.readFileSync(p,'utf8'));
    j.version='${VERSION}';
    fs.writeFileSync(p, JSON.stringify(j,null,2)+'\n');
  "
  ws_log_ok "$dir → $VERSION"
}

bump_mobile() {
  local pubspec="$(repo_dir linkkin-mobile)/pubspec.yaml"
  [[ -f "$pubspec" ]] || return 0
  sed -i "s/^version: .*/version: ${VERSION}/" "$pubspec"
  ws_log_ok "linkkin-mobile → $VERSION"
}

ws_log_info "Version bump"
for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support; do
  bump_node "$dir"
done
bump_mobile

ws_log_info "CHANGELOG"
for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support linkkin-mobile; do
  if [[ -d "$(repo_dir "$dir")/.git" ]]; then
    bash "$ROOT/scripts/generate-changelog.sh" "$(repo_dir "$dir")" "$(repo_dir "$dir")/CHANGELOG.md" "$VERSION"
  fi
done

# Workspace-level changelog
mkdir -p "$ROOT"
bash "$ROOT/scripts/generate-changelog.sh" "$(repo_dir linkkin-backend)" "$ROOT/CHANGELOG.md" "$VERSION" 2>/dev/null || true

if [[ "$NO_TAG" != "1" ]]; then
  ws_log_info "Git tag $TAG"
  for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support linkkin-mobile; do
    path="$(repo_dir "$dir")"
    [[ -d "$path/.git" ]] || continue
    [[ -f "$path/package.json" ]] && git -C "$path" add package.json
    [[ -f "$path/pubspec.yaml" ]] && git -C "$path" add pubspec.yaml
    [[ -f "$path/CHANGELOG.md" ]] && git -C "$path" add CHANGELOG.md
    git -C "$path" commit -m "chore(release): ${TAG}" 2>/dev/null || true
    git -C "$path" tag -a "$TAG" -m "Release ${TAG}" 2>/dev/null || git -C "$path" tag "$TAG" 2>/dev/null || ws_log_warn "$dir: tag failed"
    ws_log_ok "$dir tagged $TAG"
  done
fi

if [[ "$NO_PUSH" != "1" && "${PUSH_TAGS:-0}" == "1" ]]; then
  ws_log_info "Pushing tags"
  for dir in linkkin-backend linkkin-web linkkin-admin linkkin-support linkkin-mobile; do
    path="$(repo_dir "$dir")"
    [[ -d "$path/.git" ]] || continue
    git -C "$path" push origin HEAD 2>/dev/null || ws_log_warn "$dir push failed"
    git -C "$path" push origin "$TAG" 2>/dev/null || ws_log_warn "$dir tag push failed"
  done
else
  ws_log_info "Tag push skipped (set PUSH_TAGS=1 to push)"
fi

if [[ "$NO_ARCHIVE" != "1" ]]; then
  ws_log_info "Archiving artifacts → $RELEASE_DIR"
  mkdir -p "$RELEASE_DIR"
  for dir in linkkin-web linkkin-admin linkkin-support; do
    if [[ -d "$(repo_dir "$dir")/dist" ]]; then
      tar -czf "$RELEASE_DIR/${dir}.tar.gz" -C "$(repo_dir "$dir")" dist
      ws_log_ok "Archived $dir/dist"
    fi
  done
  "$ROOT/version.sh" > "$RELEASE_DIR/versions.txt" 2>/dev/null || true
fi

ws_log_ok "Release $TAG complete"
exit "$EXIT_OK"
