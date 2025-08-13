#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

usage(){ cat <<USAGE
Usage: scripts/10_separate_inst.sh <input_file> <slug>
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

source "$SCRIPT_DIR/../.venv/bin/activate"

IN="$1"; SLUG="${2:-$(basename "${IN%.*}")}" 
BASE="$SS_WORK/${SLUG}"
OUTDIR="$SS_OUT/${SLUG}"
mkdir -p "$BASE/sep1" "$OUTDIR"

MODEL_DIR="$SS_MODELS_DIR/UVR"
MODEL="UVR-MDX-NET-Inst_HQ_3.onnx"
DEVICE_OPT=""
[[ "${SS_FORCE_CPU:-0}" == 1 ]] && DEVICE_OPT="--device cpu"

cd "$BASE/sep1"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR" \
  --chunk 10 --overlap 5 --fade_overlap hann \
  ${DEVICE_OPT:-}

INST="$(find . -maxdepth 1 -type f -name '*Instrumental*.wav' -print | sort | head -n1)"
VOX="$(find . -maxdepth 1 -type f -name '*Vocals*.wav' -print | sort | head -n1)"
[ -n "${INST:-}" ] && mv "$INST" "$BASE/01_accompaniment.wav"
[ -n "${VOX:-}" ] && mv "$VOX"  "$BASE/01_vocals_mix.wav"

[ -f "$BASE/01_accompaniment.wav" ] || { echo "[ERR] Missing accompaniment"; exit 1; }
[ -f "$BASE/01_vocals_mix.wav" ]  || { echo "[ERR] Missing vocals mix"; exit 1; }

echo "[OK] Step1 done → $BASE/01_accompaniment.wav, $BASE/01_vocals_mix.wav"
