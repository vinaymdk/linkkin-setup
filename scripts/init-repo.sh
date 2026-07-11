#!/usr/bin/env bash
# Initialize linkkin-setup git repo and prepare first push.
set -euo pipefail

SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SETUP"

chmod +x *.sh scripts/*.sh scripts/lib/*.sh linkkin-radio/*.sh linkkin-radio/scripts/*.sh linkkin-radio/scripts/lib/*.sh 2>/dev/null || true

if [[ ! -d .git ]]; then
  git init
  git branch -M main
fi

REMOTE="${LINKKIN_SETUP_REMOTE:-git@github.com:vinaymdk/linkkin-setup.git}"
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$REMOTE"
fi

git add -A
git status

echo ""
echo "Review above, then:"
echo "  git commit -m \"Initial linkkin-setup: workspace ops + linkkin-radio\""
echo "  git push -u origin main"
