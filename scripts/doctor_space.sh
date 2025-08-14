#!/usr/bin/env bash
set -euo pipefail

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}
ensure_vol_mount

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
Examples:
  make setup-split
  bash scripts/gdrive_sync_models.sh
  bash scripts/run_one.sh <slug> /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index v2
USG
}
case "${1:-}" in -h|--help) usage; exit 0;; esac

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
