#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: scripts/10_separate_inst.sh <input_file> <slug>
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

source "$(dirname "$0")/../.venv/bin/activate"

IN="$1"; SLUG="${2:-$(basename "${IN%.*}")}"
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}

BASE="$SS_WORK/${SLUG}"
OUTDIR="$SS_OUT/${SLUG}"
mkdir -p "$BASE/sep1" "$OUTDIR"

MODEL_DIR="$SS_MODELS_DIR/UVR"
MODEL="UVR-MDX-NET-Inst_HQ_3.onnx"

cd "$BASE/sep1"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR"

INST=$(ls -1 *Instrumental*.wav 2>/dev/null | head -n1)
VOX=$(ls -1 *Vocals*.wav 2>/dev/null | head -n1)
[ -n "${INST:-}" ] && mv "$INST" "$BASE/01_accompaniment.wav"
[ -n "${VOX:-}" ] && mv "$VOX"  "$BASE/01_vocals_mix.wav"

[ -f "$BASE/01_accompaniment.wav" ] || { echo "[ERR] Missing accompaniment"; exit 1; }
[ -f "$BASE/01_vocals_mix.wav" ]  || { echo "[ERR] Missing vocals mix"; exit 1; }

echo "[OK] Step1 done → $BASE/01_accompaniment.wav, $BASE/01_vocals_mix.wav"
