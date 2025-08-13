#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../.venv/bin/activate"

SLUG="$1"; BASE="/vol/work/${SLUG}"; mkdir -p "$BASE/sep3"
IN="$BASE/02_main_vocal.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }
MODEL_DIR="/vol/models/UVR"; MODEL="Reverb_HQ_By_FoxJoy.onnx"

cd "$BASE/sep3"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR"

DRY=$(ls -1 *Vocals*.wav 2>/dev/null | head -n1)
WET=$(ls -1 *Instrumental*.wav 2>/dev/null | head -n1)
[ -n "${DRY:-}" ] && mv "$DRY" "$BASE/03_main_vocal_dry.wav"
[ -n "${WET:-}" ] && mv "$WET" "$BASE/03_reverb_residual.wav"

[ -f "$BASE/03_main_vocal_dry.wav" ] || { echo "[ERR] Missing dry vocal"; exit 1; }

echo "[OK] Step3 done → $BASE/03_main_vocal_dry.wav"
