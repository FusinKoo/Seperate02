#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
export LC_ALL=C.UTF-8

usage(){
  cat <<'USAGE'
Usage: scripts/gdrive_push_outputs.sh <slug>
Desc : 上传 /vol/out/<slug> 至 GDrive，并按 .src 把原始输入移至 processed/ 或 failed/
Env  : SS_OUT, SS_WORK, SS_GDRIVE_REMOTE, SS_GDRIVE_ROOT
USAGE
}
case "${1:-}" in -h|--help) usage; exit 0;; esac
[[ -n "${1:-}" ]] || { usage; exit 2; }
slug="$1"
SS_OUT=${SS_OUT:-/vol/out}
SS_WORK=${SS_WORK:-/vol/work}
SS_GDRIVE_REMOTE=${SS_GDRIVE_REMOTE:-gdrive}
SS_GDRIVE_ROOT=${SS_GDRIVE_ROOT:-Seperate02}
workdir="$SS_WORK/$slug"; srcf="$workdir/.src"
[[ -f "$srcf" ]] || { echo "[ERR] missing $srcf" >&2; exit 1; }

# 读取源信息（安全 KV 解析）
kv_get(){ awk -F'=' -v k="$1" '$1==k{sub(/^[^=]*=/,"" ); print; exit}' "$2"; }
remote_path="$(kv_get remote_path "$srcf")"
fname="$(kv_get original_name "$srcf")"
[[ -n "$remote_path" && -n "$fname" ]] || { echo "[ERR] $srcf malformed" >&2; exit 1; }
outdir="$SS_OUT/$slug"

[[ -d "$outdir" ]] || { echo "[ERR] missing outdir: $outdir"; exit 1; }

# 上传最终产物
rclone copy "$outdir" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/out/${slug}" --checksum --checkers=8 --transfers=8 --fast-list

# 判定成功/失败
pass=false
if [[ -f "$outdir/quality_report.json" ]]; then
  if grep -q '"pass"\s*:\s*true' "$outdir/quality_report.json"; then pass=true; fi
fi

if $pass; then
  # 移动原始文件到 processed
  rclone moveto "$remote_path" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/processed/${fname}" || true
  # 上传 per‑song run.log
  LOG_LOCAL="$SS_WORK/$slug/run.log"
  if [[ -f "$LOG_LOCAL" ]]; then
    TS=$(date -u +%Y%m%d)
    rclone copyto "$LOG_LOCAL" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/logs/${TS}/${slug}_run.log" --checksum || true
  fi
  # 清理工作目录（成功后）
  rm -rf "$SS_WORK/$slug" || true
else
  # 失败：移动到 failed 并写原因
  rclone moveto "$remote_path" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/failed/${fname}" || true
  reason_file="/tmp/${slug}.reason.txt"
  echo "Seperate02 failure for $slug" > "$reason_file"
  [[ -f "$outdir/quality_report.json" ]] && {
    echo "--- quality_report.json ---" >> "$reason_file"
    sed -n '1,120p' "$outdir/quality_report.json" >> "$reason_file"
  }
  rclone copyto "$reason_file" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/failed/${fname}.reason.txt"
  rm -f "$reason_file"
fi

echo "[PUSHED] $slug → out/${slug} (pass=$pass)"
