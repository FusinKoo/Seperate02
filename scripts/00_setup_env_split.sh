#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
      --locked Install from requirements-locked.txt
Examples:
  make setup-split
  make setup-lock
USG
}

: "${SS_UVR_VENV:=/vol/venvs/uvr}"
: "${SS_RVC_VENV:=/vol/venvs/rvc}"
: "${SS_CACHE_DIR:=/vol/.cache}"

LOCKED=false
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0;;
    --locked) LOCKED=true;;
  esac
done

REQ_FILE="requirements-locked.txt"
if $LOCKED && [[ ! -f "$REQ_FILE" ]]; then
  echo "[ERR] missing $REQ_FILE" >&2
  exit 2
fi

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

ensure_vol_mount

if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "[WARN] ffmpeg not found. Install with: apt-get update && apt-get install -y --no-install-recommends ffmpeg" >&2
  else
    echo "[WARN] ffmpeg not found and apt-get unavailable; please install ffmpeg manually." >&2
  fi
else
  ffmpeg -version | head -n 1
fi

# ensure string for rg checks
# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

mkdir -p "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR"

export HF_HOME="$SS_CACHE_DIR/hf"
export TRANSFORMERS_CACHE="$SS_CACHE_DIR/hf"
export TORCH_HOME="$SS_CACHE_DIR/torch"
export PIP_CACHE_DIR="$SS_CACHE_DIR/pip"
export TMPDIR=/vol/tmp
mkdir -p "$HF_HOME" "$TORCH_HOME" "$PIP_CACHE_DIR" "$TMPDIR"

if $LOCKED; then
  python3 -m venv "$SS_UVR_VENV"
  "$SS_UVR_VENV/bin/pip" install --no-cache-dir -r "$REQ_FILE"

  python3 -m venv "$SS_RVC_VENV"
  "$SS_RVC_VENV/bin/pip" install --no-cache-dir -r "$REQ_FILE"
else
  python3 -m venv "$SS_UVR_VENV"
  "$SS_UVR_VENV/bin/pip" install -U pip wheel setuptools
  "$SS_UVR_VENV/bin/pip" install --no-cache-dir -r requirements-uvr.txt

  python3 -m venv "$SS_RVC_VENV"
  "$SS_RVC_VENV/bin/python" -m pip install -U "pip<24.1" "setuptools<70" wheel
  "$SS_RVC_VENV/bin/pip" install --no-cache-dir "numpy==1.23.5"
  "$SS_RVC_VENV/bin/pip" install --no-cache-dir \\
    --index-url https://download.pytorch.org/whl/cu124 \\
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0
  "$SS_RVC_VENV/bin/pip" install --no-cache-dir -r requirements-rvc.txt
fi

"$SS_UVR_VENV/bin/pip" cache purge || true
"$SS_RVC_VENV/bin/pip" cache purge || true

UVR_BIN="$SS_UVR_VENV/bin/audio-separator"
RVC_BIN="$SS_RVC_VENV/bin/rvc"
command -v "$UVR_BIN" >/dev/null && echo "[OK] UVR binary: $UVR_BIN ($("$UVR_BIN" --version))"
command -v "$RVC_BIN" >/dev/null && echo "[OK] RVC binary: $RVC_BIN ($("$RVC_BIN" --version 2>/dev/null || echo unknown))"
df -h / /vol "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR" 2>/dev/null || df -h

echo "[OK] UVR venv: $SS_UVR_VENV"
echo "[OK] RVC venv: $SS_RVC_VENV"
