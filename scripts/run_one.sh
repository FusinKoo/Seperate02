#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# env defaults
SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}

IN="$1"; shift || true
RVC_PTH="${1:-${SS_RVC_PTH:-}}"; RVC_INDEX="${2:-${SS_RVC_INDEX:-}}"; RVC_VER="${3:-${SS_RVC_VER:-v2}}"

# 解析输入
declare slug path
if [[ "$IN" == *"/"* ]]; then
  path="$IN"
  base="$(basename "${path%.*}")"; slug="$base"
else
  slug="$IN"
  srcf="$SS_WORK/$slug/.src"; [[ -f "$srcf" ]] || { echo "[ERR] $srcf not found"; exit 1; }
  eval "$(grep -E '^(local_inbox_path|ext)=' "$srcf")"
  path="$local_inbox_path"
fi

[[ -f "$path" ]] || { echo "[ERR] input not found: $path"; exit 1; }
[[ -n "$RVC_PTH" && -f "$RVC_PTH" ]] || { echo "[ERR] RVC .pth missing"; exit 1; }
[[ -n "$RVC_INDEX" && -f "$RVC_INDEX" ]] || { echo "[ERR] RVC .index missing"; exit 1; }

# 串行步骤
bash scripts/10_separate_inst.sh "$path" "$slug"
bash scripts/20_extract_main.sh "$slug"
bash scripts/30_dereverb_denoise.sh "$slug"
bash scripts/40_rvc_convert.sh "$slug" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER"
python3 scripts/50_finalize_and_report.py --slug "$slug"
# 可选：
# bash scripts/60_optional_mixdown.sh "$slug"

echo "[DONE] $slug → $SS_OUT/$slug"
