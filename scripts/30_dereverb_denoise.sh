#!/usr/bin/env bash
# step30 (STRICT): dereverb/denoise via UVR + Reverb_HQ_By_FoxJoy.onnx only.
# - No fallback. Missing model or binary -> hard error.
# - Output: /vol/work/<slug>/03_main_vocal_clean.wav
set -euo pipefail

usage() {
  cat <<'USG'
Usage: scripts/30_dereverb_denoise.sh <slug>
Desc : Produce 03_main_vocal_clean.wav from 02_main_vocal.wav using UVR dereverb model.
Env  : SS_WORK (/vol/work), SS_MODELS_DIR (/vol/models), SS_UVR_VENV (/vol/venvs/uvr),
       SS_UVR_DEREVERB_MODEL (default: Reverb_HQ_By_FoxJoy.onnx),
       SS_UVR_USE_SOUNDFILE (optional: 1 to enable --use_soundfile)
USG
}

SLUG=${1:-}
[[ -n "${SLUG:-}" ]] || { usage; exit 2; }

# env
set +u; [ -f .env ] && . .env; set -u
SS_WORK="${SS_WORK:-/vol/work}"
SS_MODELS_DIR="${SS_MODELS_DIR:-/vol/models}"
SS_UVR_VENV="${SS_UVR_VENV:-/vol/venvs/uvr}"
MODEL_DIR="${SS_MODELS_DIR}/UVR"
MODEL_NAME="${SS_UVR_DEREVERB_MODEL:-Reverb_HQ_By_FoxJoy.onnx}"
AS_BIN="${SS_UVR_VENV}/bin/audio-separator"

IN="$SS_WORK/$SLUG/02_main_vocal.wav"
OUT="$SS_WORK/$SLUG/03_main_vocal_clean.wav"
TMP_OUTDIR="$SS_WORK/$SLUG/30_dereverb.tmp"

# preflight
[[ -f "$IN" ]] || { echo "[ERR] $IN not found"; exit 2; }
[[ -x "$AS_BIN" ]] || { echo "[ERR] audio-separator not found: $AS_BIN (run setup)"; exit 2; }
[[ -f "$MODEL_DIR/$MODEL_NAME" ]] || {
  echo "[ERR] missing dereverb model: $MODEL_DIR/$MODEL_NAME"; 
  echo "HINT: put it in Google Drive models/UVR/ and sync down: scripts/gdrive_sync_models.sh"; 
  exit 90; 
}

# run UVR with the specified model to a dedicated tmp dir
rm -rf "$TMP_OUTDIR"
mkdir -p "$TMP_OUTDIR"

cmd=( "$AS_BIN" -m "$MODEL_NAME" --model_file_dir "$MODEL_DIR" \
      --output_dir "$TMP_OUTDIR" --output_format WAV \
      --mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0 --amplification 0 )
[[ "${SS_UVR_USE_SOUNDFILE:-0}" = "1" ]] && cmd+=( --use_soundfile )

echo "[INF] UVR dereverb model: $MODEL_DIR/$MODEL_NAME"
"${cmd[@]}" "$IN"

# pick exactly one wav from tmp; if multiple, choose the newest one deterministically
mapfile -t WAVS < <(find "$TMP_OUTDIR" -maxdepth 1 -type f -name '*.wav' -printf '%T@ %p\n' | sort -nr | awk '{ $1=""; sub(/^ /,""); print }')
[[ ${#WAVS[@]} -ge 1 ]] || { echo "[ERR] UVR produced no wav in $TMP_OUTDIR"; exit 3; }
SEL="${WAVS[0]}"

# normalize container/format to 48k/16-bit stereo for downstream consistency
ffmpeg -y -v error -i "$SEL" -ac 2 -ar 48000 -c:a pcm_s16le "$OUT"

[[ -f "$OUT" ]] || { echo "[ERR] step30 output missing: $OUT"; exit 3; }
echo "[OK] 30 -> $(basename "$OUT")"
