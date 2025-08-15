#!/usr/bin/env bash
set -euo pipefail
usage(){
  cat <<USG
Usage: scripts/30_dereverb_denoise.sh <slug>
Example: bash scripts/30_dereverb_denoise.sh myslug
Env    : SS_WORK, SS_MODELS_DIR, SS_UVR_VENV
USG
}
case "${1:-}" in -h|--help) usage; exit 0;; esac
SLUG=${1:-}; [[ -n "${SLUG:-}" ]] || { usage; exit 2; }
set +u; [ -f .env ] && . .env; set -u
SS_WORK="${SS_WORK:-/vol/work}"; SS_MODELS_DIR="${SS_MODELS_DIR:-/vol/models}"; SS_UVR_VENV="${SS_UVR_VENV:-/vol/venvs/uvr}"
UVR_BIN="$SS_UVR_VENV/bin/audio-separator"; MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="Reverb_HQ_By_FoxJoy.onnx"
WORK_DIR="$SS_WORK/$SLUG"; IN="$WORK_DIR/02_main_vocal.wav"; [[ -f "$IN" ]] || { echo "[ERR] missing $IN"; exit 3; }
"$UVR_BIN" -m "$MODEL" --model_file_dir "$MODEL_DIR" --output_dir "$WORK_DIR" --output_format WAV \
  --mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0 --amplification 0 "$IN"
shopt -s nullglob
cand=( "$WORK_DIR"/*"(No Reverb)"*Reverb_HQ_By_FoxJoy*.wav );
[[ ${#cand[@]} -ge 1 ]] || cand=( "$WORK_DIR"/*"(Dry)"*Reverb_HQ_By_FoxJoy*.wav );
[[ ${#cand[@]} -ge 1 ]] || cand=( $(ls "$WORK_DIR"/*Reverb_HQ_By_FoxJoy*.wav 2>/dev/null | grep -vi 'Reverb' || true) );
[[ ${#cand[@]} -ge 1 ]] || { echo "[ERR] dry vocal not found"; exit 3; }
mv -f "${cand[0]}" "$WORK_DIR/03_main_vocal_dry.wav"; echo "[OK] 30 -> 03_main_vocal_dry.wav"
