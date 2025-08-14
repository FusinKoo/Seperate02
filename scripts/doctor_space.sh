#!/usr/bin/env bash
set -euo pipefail

ROOT_THR=5
VOL_THR=20

# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

df -h / /vol

root_free=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4);print $4}')
vol_free=$(df -BG /vol | awk 'NR==2{gsub(/G/,"",$4);print $4}')
if [ "$root_free" -lt "$ROOT_THR" ] || [ "$vol_free" -lt "$VOL_THR" ]; then
  echo "[ERR] insufficient disk space" >&2
  exit 1
fi

if command -v nvidia-smi >/dev/null; then
  nvidia-smi | head -n 15
else
  echo "nvidia-smi not found" >&2
fi

echo "[TOP /]"
du -xh -d1 / | sort -h | tail
echo "[TOP /vol]"
du -xh -d1 /vol | sort -h | tail
