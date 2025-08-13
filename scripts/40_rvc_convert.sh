#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: scripts/40_rvc_convert.sh <slug> <rvc_pth> [index] [v1|v2]
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

source "$(dirname "$0")/../.venv/bin/activate"

SLUG="$1"; RVC_PTH="$2"; RVC_INDEX="${3:-}"; RVC_VER="${4:-v2}"
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}
BASE="$SS_WORK/${SLUG}"; OUTDIR="$SS_OUT/${SLUG}"; mkdir -p "$OUTDIR"
IN="$BASE/03_main_vocal_dry.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }

export RVC_ASSETS_DIR="$SS_ASSETS_DIR"

python -m rvc_python cli \
  -i "$IN" \
  -o "$OUTDIR/04_vocal_converted.wav" \
  -mp "$RVC_PTH" \
  ${RVC_INDEX:+-ip "$RVC_INDEX"} \
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
