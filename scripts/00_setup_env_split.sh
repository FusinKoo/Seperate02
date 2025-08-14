#!/usr/bin/env bash
set -euo pipefail

retry() {
  local n=0
  until "$@"; do
    n=$((n+1))
    if [ "$n" -ge 2 ]; then
      return 1
    fi
    echo "[WARN] retry $n for: $*" >&2
    sleep 1
  done
}

UVR=${SS_UVR_VENV:-/opt/venvs/uvr}
RVC=${SS_RVC_VENV:-/opt/venvs/rvc}
CACHE_DIR=${SS_CACHE_DIR:-/vol/.cache}
mkdir -p "$UVR" "$RVC" "$CACHE_DIR"

export HF_HOME="$CACHE_DIR/huggingface"
export TRANSFORMERS_CACHE="$CACHE_DIR/huggingface"
export TORCH_HOME="$CACHE_DIR/torch"
export PIP_CACHE_DIR="$CACHE_DIR/pip"

try python3 -m venv "$UVR" && "$UVR/bin/pip" install -U pip wheel setuptools
try "$UVR/bin/pip" install --no-cache-dir -r requirements-uvr.txt
try python3 -m venv "$RVC" && "$RVC/bin/pip" install -U pip wheel setuptools
try "$RVC/bin/pip" install --no-cache-dir \
  torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
  --index-url https://download.pytorch.org/whl/cu124
try "$RVC/bin/pip" install --no-cache-dir -r requirements-rvc.txt
"$UVR/bin/pip" cache purge || true; "$RVC/bin/pip" cache purge || true

if command -v df >/dev/null; then
  df -h "$UVR" "$RVC" "$CACHE_DIR" /vol 2>/dev/null || df -h
fi

echo "[INFO] UVR venv: $UVR"
echo "[INFO] RVC venv: $RVC"
echo "[HINT] export PATH=\"$UVR/bin:$RVC/bin:\$PATH\""

which "$UVR/bin/audio-separator" || true
which "$RVC/bin/rvc" || true
