#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: 10_A_run.sh <input_wav> <slug>"
  exit 0
fi
DIR=$(cd "$(dirname "$0")" && pwd)
"${DIR}/10_separate_inst.sh" "$@"
