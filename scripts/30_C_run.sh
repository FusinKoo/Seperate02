#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: 30_C_run.sh <slug>"
  exit 0
fi
DIR=$(cd "$(dirname "$0")" && pwd)
"${DIR}/30_dereverb_denoise.sh" "$@"
