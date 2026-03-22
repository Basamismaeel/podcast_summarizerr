#!/usr/bin/env bash
# Run on a connected iPhone with a Gemini key for this build only (optional).
# The flag must be passed to `flutter run`, not run alone in the shell.
#
#   ./tool/flutter_run_ios.sh
#   GEMINI_API_KEY='paste_AI_Studio_key_here' ./tool/flutter_run_ios.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  exec flutter run --dart-define="GEMINI_API_KEY=${GEMINI_API_KEY}" "$@"
else
  exec flutter run "$@"
fi
