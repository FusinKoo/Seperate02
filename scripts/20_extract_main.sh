#!/usr/bin/env bash
set -euo pipefail
usage(){ echo "Usage: $0 <slug>"; }

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

SLUG=${1:-}
[[ -n "${SLUG:-}" ]] || { usage; exit 2; }

set +u; [ -f .env ] && . .env; set -u
SS_WORK="${SS_WORK:-/vol/work}"; SS_MODELS_DIR="${SS_MODELS_DIR:-/vol/models}"; SS_UVR_VENV="${SS_UVR_VENV:-/vol/venvs/uvr}"
UVR_BIN="$SS_UVR_VENV/bin/audio-separator"; MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="Kim_Vocal_2.onnx"
WORK_DIR="$SS_WORK/$SLUG"; VOC="$WORK_DIR/01_vocals_mix.wav"
[[ -f "$VOC" ]] || { echo "[ERR] $VOC not found"; exit 2; }
# 规范化（幂等）
tmp="$WORK_DIR/01_vocals_mix.norm.wav"
ffmpeg -y -v error -i "$VOC" -ac 2 -ar 48000 -c:a pcm_s16le "$tmp"
mv -f "$tmp" "$VOC"
"$UVR_BIN" -m "$MODEL" --model_file_dir "$MODEL_DIR" --output_dir "$WORK_DIR" --output_format WAV \
  --mdx_segment_size 8 --mdx_overlap 4 --fade_overlap hann --normalization 1.0 --amplification 0 "$VOC"
shopt -s nullglob
main=( "$WORK_DIR"/*"(Vocals)"*Kim_Vocal_2*.wav )
[[ ${#main[@]} -ge 1 ]] || { echo "[ERR] main vocal not found"; exit 3; }
mv -f "${main[0]}" "$WORK_DIR/02_main_vocal.wav"; echo "[OK] 20 -> 02_main_vocal.wav"
