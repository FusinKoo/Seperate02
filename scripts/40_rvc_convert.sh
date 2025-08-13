#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../.venv/bin/activate"

SLUG="$1"; RVC_PTH="$2"; RVC_INDEX="${3:-}"; RVC_VER="${4:-v2}"
BASE="/vol/work/${SLUG}"; OUTDIR="/vol/out/${SLUG}"; mkdir -p "$OUTDIR"
IN="$BASE/03_main_vocal_dry.wav"; [ -f "$IN" ] || { echo "[ERR] $IN"; exit 1; }

export RVC_ASSETS_DIR="/vol/assets"

# 调用 rvc-python 的 CLI；如该版本选项有变更，Agent 需查询 --help 并等价替换为同义参数
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
