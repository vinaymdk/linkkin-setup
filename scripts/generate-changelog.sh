#!/usr/bin/env bash
# Generate CHANGELOG.md from git commits since last tag.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${1:-$ROOT/linkkin-backend}"
OUT="${2:-$REPO_DIR/CHANGELOG.md}"
VERSION="${3:-}"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "Not a git repo: $REPO_DIR" >&2
  exit 1
fi

since_tag=""
if git -C "$REPO_DIR" describe --tags --abbrev=0 >/dev/null 2>&1; then
  since_tag="$(git -C "$REPO_DIR" describe --tags --abbrev=0)"
fi

range="${since_tag:+${since_tag}..}HEAD"
ver_label="${VERSION:-Unreleased}"
ver_label="${ver_label#v}"

added=() fixed=() improved=() other=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  msg="${line#*: }"
  lower="$(echo "$msg" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" == add* || "$lower" == feat* || "$lower" == new* ]]; then
    added+=("$msg")
  elif [[ "$lower" == fix* || "$lower" == bug* ]]; then
    fixed+=("$msg")
  elif [[ "$lower" == improve* || "$lower" == refactor* || "$lower" == perf* || "$lower" == update* ]]; then
    improved+=("$msg")
  else
    other+=("$msg")
  fi
done < <(git -C "$REPO_DIR" log "$range" --pretty=format:"%s" 2>/dev/null || true)

{
  echo "# Changelog"
  echo ""
  echo "## v${ver_label}"
  echo ""
  if [[ ${#added[@]} -gt 0 ]]; then
    echo "### Added"
    for i in "${added[@]}"; do echo "- $i"; done
    echo ""
  fi
  if [[ ${#improved[@]} -gt 0 ]]; then
    echo "### Improved"
    for i in "${improved[@]}"; do echo "- $i"; done
    echo ""
  fi
  if [[ ${#fixed[@]} -gt 0 ]]; then
    echo "### Fixed"
    for i in "${fixed[@]}"; do echo "- $i"; done
    echo ""
  fi
  if [[ ${#other[@]} -gt 0 ]]; then
    echo "### Other"
    for i in "${other[@]}"; do echo "- $i"; done
    echo ""
  fi
  if [[ -f "$OUT" ]]; then
    echo "---"
    echo ""
    tail -n +2 "$OUT" | sed '/^# Changelog/d' | sed '1{/^$/d}'
  fi
} > "${OUT}.tmp"

mv "${OUT}.tmp" "$OUT"
echo "CHANGELOG updated: $OUT"
