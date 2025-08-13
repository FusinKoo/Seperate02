#!/usr/bin/env bash
set -euo pipefail

RVC_PTH="$1"              # 共用的 RVC 模型路径
RVC_INDEX="${2:-}"        # 可选 index
RVC_VER="${3:-v2}"
PARALLEL="${SS_PARALLEL_JOBS:-4}"

# 遍历 /vol/inbox 下的音频文件
find /vol/inbox -maxdepth 1 -type f \( -iname '*.wav' -o -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' \) | sort |
while IFS= read -r f; do
  slug=$(basename "${f%.*}")
  echo "./scripts/run_one.sh \"$f\" $slug \"$RVC_PTH\" \"$RVC_INDEX\" $RVC_VER"
done | xargs -I{} -P "$PARALLEL" bash -lc {}
