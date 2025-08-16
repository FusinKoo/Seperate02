#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

: "${SS_UVR_VENV:=${SS_VENVS_DIR}/uvr}"; : "${SS_RVC_VENV:=${SS_VENVS_DIR}/rvc}"
UVR_BIN="$SS_UVR_VENV/bin"; RVC_BIN="$SS_RVC_VENV/bin"

usage(){ cat <<USAGE
Usage: scripts/40_rvc_convert.sh <slug> <rvc_pth> <rvc.index> [v1|v2]
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

# requires $SS_UVR_VENV/bin/audio-separator and RVC CLI or module
command -v "$UVR_BIN/audio-separator" >/dev/null || { echo "[ERR] audio-separator not found; run scripts/00_setup_env_split.sh"; exit 2; }
if [ -x "$RVC_BIN/rvc" ]; then
  RVC_CMD=("$RVC_BIN/rvc")
elif [ -x "$SS_RVC_VENV/bin/python" ]; then
  RVC_CMD=("$SS_RVC_VENV/bin/python" -m rvc)
else
  echo "[ERR] rvc not found; run scripts/00_setup_env_split.sh"; exit 2;
fi

SLUG="$1"; RVC_PTH="$2"; RVC_INDEX="$3"; RVC_VER="${4:-v2}"
BASE="$SS_WORK/${SLUG}"; OUTDIR="$SS_OUT/${SLUG}"; mkdir -p "$OUTDIR"
IN="$BASE/03_main_vocal_dry.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }

[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC model not found: $RVC_PTH. Place model in $SS_MODELS_DIR/RVC/ or set SS_RVC_PTH"; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC index not found: $RVC_INDEX. Place index in $SS_MODELS_DIR/RVC/ or set SS_RVC_INDEX"; exit 1; }
[[ "$RVC_VER" == v1 || "$RVC_VER" == v2 ]] || { echo "[ERR] RVC version must be v1 or v2"; exit 1; }

export RVC_ASSETS_DIR="$SS_ASSETS_DIR"

"${RVC_CMD[@]}" infer \
  -i "$IN" \
  -o "$OUTDIR/04_vocal_converted.wav" \
  -mp "$RVC_PTH" \
  -ip "$RVC_INDEX" \
  -v "$RVC_VER" \
  -de cuda:0 \
  -me rmvpe \
  -pi 0 \
  -ir 0.75 \
  -pr 0.33 \
  -rmr 0.0 \
  -rsr 48000

[ -f "$OUTDIR/04_vocal_converted.wav" ] || { echo "[ERR] RVC failed"; exit 1; }

echo "[OK] Step4 done → $OUTDIR/04_vocal_converted.wav"
