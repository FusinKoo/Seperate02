#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../.venv/bin/activate"

IN="$1"                             # 全路径，如 /vol/inbox/<slug>.wav
SLUG="${2:-$(basename "${IN%.*}")}"
BASE="/vol/work/${SLUG}"
OUTDIR="/vol/out/${SLUG}"
mkdir -p "$BASE/sep1" "$OUTDIR"

MODEL_DIR="/vol/models/UVR"
MODEL="UVR-MDX-NET-Inst_HQ_3.onnx"

# 执行真实分离（输出到当前目录）
cd "$BASE/sep1"
audio-separator "$IN" \
  --model_filename "$MODEL" \
  --model_file_dir "$MODEL_DIR"

# 规整命名
INST=$(ls -1 *Instrumental*.wav 2>/dev/null | head -n1)
VOX=$(ls -1 *Vocals*.wav 2>/dev/null | head -n1)
[ -n "${INST:-}" ] && mv "$INST" "$BASE/01_accompaniment.wav"
[ -n "${VOX:-}" ] && mv "$VOX"  "$BASE/01_vocals_mix.wav"

# 守卫
[ -f "$BASE/01_accompaniment.wav" ] || { echo "[ERR] Missing accompaniment"; exit 1; }
[ -f "$BASE/01_vocals_mix.wav" ]  || { echo "[ERR] Missing vocals mix"; exit 1; }

echo "[OK] Step1 done → $BASE/01_accompaniment.wav, $BASE/01_vocals_mix.wav"
