#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

usage(){ cat <<USAGE
Usage: scripts/40_rvc_convert.sh <slug> <rvc_pth> <rvc.index> [v1|v2]
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

source "$SCRIPT_DIR/../.venv/bin/activate"

SLUG="$1"; RVC_PTH="$2"; RVC_INDEX="$3"; RVC_VER="${4:-v2}"
BASE="$SS_WORK/${SLUG}"; OUTDIR="$SS_OUT/${SLUG}"; mkdir -p "$OUTDIR"
IN="$BASE/03_main_vocal_dry.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }

[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC model not found: $RVC_PTH. Place model in $SS_MODELS_DIR/RVC/ or set SS_RVC_PTH"; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC index not found: $RVC_INDEX. Place index in $SS_MODELS_DIR/RVC/ or set SS_RVC_INDEX"; exit 1; }
[[ "$RVC_VER" == v1 || "$RVC_VER" == v2 ]] || { echo "[ERR] RVC version must be v1 or v2"; exit 1; }

export RVC_ASSETS_DIR="$SS_ASSETS_DIR"

python -m rvc_python cli \
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
