#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: 40_D_rvc.sh <slug> <pth> <index> <ver>"
  exit 0
fi
DIR=$(cd "$(dirname "$0")" && pwd)
"${DIR}/40_rvc_convert.sh" "$@"
