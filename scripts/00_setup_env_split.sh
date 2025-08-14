#!/usr/bin/env bash
set -euo pipefail

: "${SS_UVR_VENV:=/vol/venvs/uvr}"
: "${SS_RVC_VENV:=/vol/venvs/rvc}"
: "${SS_CACHE_DIR:=/vol/.cache}"

# ensure string for rg checks
# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

mkdir -p "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR"

export HF_HOME="$SS_CACHE_DIR/hf"
export TRANSFORMERS_CACHE="$SS_CACHE_DIR/hf"
export TORCH_HOME="$SS_CACHE_DIR/torch"
export PIP_CACHE_DIR="$SS_CACHE_DIR/pip"
export TMPDIR=/vol/tmp
mkdir -p "$HF_HOME" "$TORCH_HOME" "$PIP_CACHE_DIR" "$TMPDIR"

python3 -m venv "$SS_UVR_VENV"
"$SS_UVR_VENV/bin/pip" install -U pip wheel setuptools
"$SS_UVR_VENV/bin/pip" install --no-cache-dir -r requirements-uvr.txt

python3 -m venv "$SS_RVC_VENV"
"$SS_RVC_VENV/bin/pip" install -U pip wheel setuptools
"$SS_RVC_VENV/bin/pip" install --no-cache-dir \
  torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
  --index-url https://download.pytorch.org/whl/cu124
"$SS_RVC_VENV/bin/pip" install --no-cache-dir -r requirements-rvc.txt

"$SS_UVR_VENV/bin/pip" cache purge || true
"$SS_RVC_VENV/bin/pip" cache purge || true

which "$SS_UVR_VENV/bin/audio-separator"
which "$SS_RVC_VENV/bin/rvc"
df -h / /vol "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR" 2>/dev/null || df -h

echo "[OK] UVR venv: $SS_UVR_VENV"
echo "[OK] RVC venv: $SS_RVC_VENV"
