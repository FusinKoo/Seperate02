#!/usr/bin/env bash
set -euo pipefail
usage(){
  cat <<USG
Usage: scripts/20_extract_main.sh <slug>
Example: bash scripts/20_extract_main.sh myslug
Env    : SS_WORK, SS_MODELS_DIR, SS_UVR_VENV
USG
}
case "${1:-}" in -h|--help) usage; exit 0;; esac
SLUG=${1:-}; [[ -n "${SLUG:-}" ]] || { usage; exit 2; }
set +u; [ -f .env ] && . .env; set -u
SS_WORK="${SS_WORK:-/vol/work}"; SS_MODELS_DIR="${SS_MODELS_DIR:-/vol/models}"; SS_UVR_VENV="${SS_UVR_VENV:-/vol/venvs/uvr}"
UVR_BIN="$SS_UVR_VENV/bin/audio-separator"; MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="Kim_Vocal_2.onnx"
WORK_DIR="$SS_WORK/$SLUG"; IN="$WORK_DIR/01_vocals_mix.wav"; [[ -f "$IN" ]] || { echo "[ERR] missing $IN"; exit 3; }
"$UVR_BIN" -m "$MODEL" --model_file_dir "$MODEL_DIR" --output_dir "$WORK_DIR" --output_format WAV \
  --mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0 --amplification 0 "$IN"
shopt -s nullglob
main=( "$WORK_DIR"/*"(Vocals)"*Kim_Vocal_2*.wav )
[[ ${#main[@]} -ge 1 ]] || { echo "[ERR] main vocal not found"; exit 3; }
mv -f "${main[0]}" "$WORK_DIR/02_main_vocal.wav"; echo "[OK] 20 -> 02_main_vocal.wav"
