#!/usr/bin/env bash
set -euo pipefail

IN="$1"            # /vol/inbox/<slug>.<ext>
SLUG="${2:-$(basename "${IN%.*}")}"
RVC_PTH="$3"       # /vol/models/RVC/<model>.pth
RVC_INDEX="${4:-}"  # 可选：/vol/models/RVC/<model>.index
RVC_VER="${5:-v2}"

bash scripts/10_separate_inst.sh "$IN" "$SLUG"
bash scripts/20_extract_main.sh "$SLUG"
bash scripts/30_dereverb_denoise.sh "$SLUG"
bash scripts/40_rvc_convert.sh "$SLUG" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER"
python scripts/50_finalize_and_report.py --slug "$SLUG"
# 可选：
# bash scripts/60_optional_mixdown.sh "$SLUG"

echo "[DONE] /vol/out/${SLUG}"
