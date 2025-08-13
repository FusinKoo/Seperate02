#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../.venv/bin/activate"

SLUG="$1"; BASE="/vol/work/${SLUG}"; mkdir -p "$BASE/sep2"
IN="$BASE/01_vocals_mix.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }
MODEL_DIR="/vol/models/UVR"; MODEL="Kim_Vocal_2.onnx"

cd "$BASE/sep2"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR"

MAIN=$(ls -1 *Vocals*.wav 2>/dev/null | head -n1)
REST=$(ls -1 *Instrumental*.wav 2>/dev/null | head -n1)
[ -n "${MAIN:-}" ] && mv "$MAIN" "$BASE/02_main_vocal.wav"
[ -n "${REST:-}" ] && mv "$REST" "$BASE/02_backing_rest.wav"

[ -f "$BASE/02_main_vocal.wav" ] || { echo "[ERR] Missing main vocal"; exit 1; }

echo "[OK] Step2 done → $BASE/02_main_vocal.wav"
