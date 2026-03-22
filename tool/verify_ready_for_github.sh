#!/usr/bin/env bash
# Run before git push: fails if .env (or other secret files) are tracked.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -n "$(git ls-files -- .env)" ]]; then
  echo "ERROR: .env is tracked by git. Fix with:"
  echo "  git rm --cached .env"
  echo "Then commit. Rotate any keys that were ever pushed."
  exit 1
fi

bad_env=$(git ls-files | grep -E '^\.env\.' | grep -v '^\.env\.example$' || true)
if [[ -n "$bad_env" ]]; then
  echo "ERROR: Tracked env files (should not commit real secrets):"
  echo "$bad_env"
  exit 1
fi

if git grep -n 'AIzaSy' -- '*.dart' '*.yaml' '*.json' 2>/dev/null; then
  echo "ERROR: Possible Google API key literal in tracked file(s) above."
  exit 1
fi

echo "OK: .env not tracked; no AIzaSy… literals in dart/yaml/json."
