#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

: "${SS_UVR_VENV:=/opt/venvs/uvr}"; : "${SS_RVC_VENV:=/opt/venvs/rvc}"
: "${SS_CACHE_DIR:=/vol/.cache}"
UVR_BIN="$SS_UVR_VENV/bin"; RVC_BIN="$SS_RVC_VENV/bin"
command -v "$SS_UVR_VENV/bin/audio-separator" >/dev/null || { echo "[ERR] audio-separator not found; run scripts/00_setup_env_split.sh"; exit 2; }

usage(){ cat <<USAGE
Usage: scripts/30_dereverb_denoise.sh <slug>
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0


SLUG="$1"
BASE="$SS_WORK/${SLUG}"; mkdir -p "$BASE/sep3"
IN="$BASE/02_main_vocal.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }
MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="Reverb_HQ_By_FoxJoy.onnx"
DEVICE_OPT=""
[[ "${SS_FORCE_CPU:-0}" == 1 ]] && DEVICE_OPT="--device cpu"

cd "$BASE/sep3"
"$SS_UVR_VENV/bin/audio-separator" "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR" \
  --chunk 8 --overlap 4 --fade_overlap hann \
  ${DEVICE_OPT:-}

DRY="$(find . -maxdepth 1 -type f -name '*Vocals*.wav' -print | sort | head -n1)"
WET="$(find . -maxdepth 1 -type f -name '*Instrumental*.wav' -print | sort | head -n1)"
[ -n "${DRY:-}" ] && mv "$DRY" "$BASE/03_main_vocal_dry.wav"
[ -n "${WET:-}" ] && mv "$WET" "$BASE/03_reverb_residual.wav"

[ -f "$BASE/03_main_vocal_dry.wav" ] || { echo "[ERR] Missing dry vocal"; exit 1; }

echo "[OK] Step3 done → $BASE/03_main_vocal_dry.wav"
