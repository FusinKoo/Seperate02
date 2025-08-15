#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
export LC_ALL=C.UTF-8

usage(){
  cat <<'USAGE'
Usage: scripts/gdrive_push_outputs.sh [--dry-run] <slug>
Desc : 上传 /vol/out/<slug> 至 GDrive，并按 .src 把原始输入移至 processed/ 或 failed/
Env  : SS_OUT, SS_WORK, SS_GDRIVE_REMOTE, SS_GDRIVE_ROOT
USAGE
}
ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

DRY_RUN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --dry-run) DRY_RUN="--dry-run"; shift;;
    *) break;;
  esac
done
ensure_vol_mount
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
RCLONE_OPTS=(--checksum --fast-list --transfers "${SS_RCLONE_TRANSFERS:-4}" --checkers "${SS_RCLONE_CHECKERS:-8}" --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}" --tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}")
cmd=(rclone copy "$outdir" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/out/${slug}" "${RCLONE_OPTS[@]}")
[[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
echo "+ ${cmd[*]}"
"${cmd[@]}"

# 判定成功/失败
pass=false
if [[ -f "$outdir/quality_report.json" ]]; then
  if grep -q '"pass"\s*:\s*true' "$outdir/quality_report.json"; then pass=true; fi
fi

if $pass; then
  # 移动原始文件到 processed
  cmd=(rclone moveto "$remote_path" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/processed/${fname}" "${RCLONE_OPTS[@]}")
  [[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
  echo "+ ${cmd[*]}"
  "${cmd[@]}" || true
  # 上传 per‑song run.log
  LOG_LOCAL="$SS_WORK/$slug/run.log"
  if [[ -f "$LOG_LOCAL" ]]; then
    TS=$(date -u +%Y%m%d)
    cmd=(rclone copyto "$LOG_LOCAL" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/logs/${TS}/${slug}_run.log" "${RCLONE_OPTS[@]}")
    [[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
    echo "+ ${cmd[*]}"
    "${cmd[@]}" || true
  fi
  # 清理工作目录（成功后）
  rm -rf "$SS_WORK/$slug" || true
else
  # 失败：移动到 failed 并写原因
  cmd=(rclone moveto "$remote_path" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/failed/${fname}" "${RCLONE_OPTS[@]}")
  [[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
  echo "+ ${cmd[*]}"
  "${cmd[@]}" || true
  reason_file="/tmp/${slug}.reason.txt"
  echo "Seperate02 failure for $slug" > "$reason_file"
  [[ -f "$outdir/quality_report.json" ]] && {
    echo "--- quality_report.json ---" >> "$reason_file"
    sed -n '1,120p' "$outdir/quality_report.json" >> "$reason_file"
  }
  # 追加步骤日志尾部（若存在）
  if [[ -f "$SS_WORK/$slug/run.log" ]]; then
    echo -e "\n--- run.log (tail -n 200) ---" >> "$reason_file"
    tail -n 200 "$SS_WORK/$slug/run.log" >> "$reason_file" || true
  fi
  cmd=(rclone copyto "$reason_file" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/inbox/failed/${fname}.reason.txt" "${RCLONE_OPTS[@]}")
  [[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
  echo "+ ${cmd[*]}"
  "${cmd[@]}"
  rm -f "$reason_file"
fi

echo "[PUSHED] $slug → out/${slug} (pass=$pass)"
