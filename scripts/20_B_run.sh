#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: 20_B_run.sh <slug>"
  exit 0
fi
DIR=$(cd "$(dirname "$0")" && pwd)
"${DIR}/20_extract_main.sh" "$@"
