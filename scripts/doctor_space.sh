#!/usr/bin/env bash
set -euo pipefail

ROOT_THR=5
VOL_THR=20
CACHE_DIR=${SS_CACHE_DIR:-/vol/.cache}

check_space() {
  local dir="$1"; local thr="$2"
  local avail
  avail=$(df -BG "$dir" | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  if [ "$avail" -lt "$thr" ]; then
    echo "[ERR] $dir free ${avail}G < ${thr}G" >&2
    du -xh "$dir" -d1 | sort -h | tail
    exit 1
  fi
}

df -h / /vol "$CACHE_DIR"
check_space / "$ROOT_THR"
check_space /vol "$VOL_THR"

if command -v nvidia-smi >/dev/null; then
  nvidia-smi --query-gpu=name,driver_version,cuda_version --format=csv,noheader | head -n1
else
  echo "nvidia-smi not found" >&2
fi
