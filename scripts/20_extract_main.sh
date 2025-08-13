#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

usage(){ cat <<USAGE
Usage: scripts/20_extract_main.sh <slug>
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

source "$SCRIPT_DIR/../.venv/bin/activate"

SLUG="$1"
BASE="$SS_WORK/${SLUG}"; mkdir -p "$BASE/sep2"
IN="$BASE/01_vocals_mix.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }
MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="Kim_Vocal_2.onnx"
DEVICE_OPT=""
[[ "${SS_FORCE_CPU:-0}" == 1 ]] && DEVICE_OPT="--device cpu"

cd "$BASE/sep2"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR" \
  --chunk 8 --overlap 4 --fade_overlap hann \
  ${DEVICE_OPT:-}

MAIN=$(ls -1 *Vocals*.wav 2>/dev/null | head -n1)
REST=$(ls -1 *Instrumental*.wav 2>/dev/null | head -n1)
[ -n "${MAIN:-}" ] && mv "$MAIN" "$BASE/02_main_vocal.wav"
[ -n "${REST:-}" ] && mv "$REST" "$BASE/02_backing_rest.wav"

[ -f "$BASE/02_main_vocal.wav" ] || { echo "[ERR] Missing main vocal"; exit 1; }

echo "[OK] Step2 done → $BASE/02_main_vocal.wav"
