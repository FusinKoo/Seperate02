#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"
export LC_ALL=C.UTF-8

: "${SS_GDRIVE_REMOTE:=gdrive}"
if ! rclone listremotes 2>/dev/null | grep -q "^${SS_GDRIVE_REMOTE}:"; then
  echo "[ERR] rclone remote '${SS_GDRIVE_REMOTE}:' not found. Set SS_GDRIVE_REMOTE or configure rclone (RCLONE_CONFIG=$RCLONE_CONFIG)." >&2
  exit 2
fi

usage(){
  cat <<'USAGE'
Usage: scripts/gdrive_push_outputs.sh [--dry-run] <slug>
Desc : 上传 ${SS_OUT}/<slug> 至 GDrive，并按 .src 把原始输入移至 processed/ 或 failed/
Env  : SS_OUT, SS_WORK, SS_GDRIVE_REMOTE, SS_GDRIVE_ROOT
Options:
  --dry-run  Show rclone operations without transferring files
USAGE
}
ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --dry-run) DRY_RUN=true; shift;;
    *) break;;
  esac
done
ensure_vol_mount
[[ $# -gt 0 ]] || { usage; exit 2; }
slug="$1"
if [ -z "${SS_GDRIVE_ROOT+x}" ]; then
  SS_GDRIVE_ROOT="Seperate02"
fi
_root="$SS_GDRIVE_ROOT"
[ "$_root" = "." ] && _root=""
REMOTE_PREFIX="${SS_GDRIVE_REMOTE}:${_root:+${_root}/}"
echo "[DBG] REMOTE_PREFIX=${REMOTE_PREFIX}" >&2
workdir="$SS_WORK/$slug"; srcf="$workdir/.src"
[[ -f "$srcf" ]] || { echo "[ERR] missing $srcf" >&2; exit 1; }

# 读取源信息（安全 KV 解析）
kv_get(){ awk -F'=' -v k="$1" '$1==k{sub(/^[^=]*=/,"" ); print; exit}' "$2"; }
remote_path="$(kv_get remote_path "$srcf")"
fname="$(kv_get original_name "$srcf")"
[[ -n "$remote_path" && -n "$fname" ]] || { echo "[ERR] $srcf malformed" >&2; exit 1; }
outdir="$SS_OUT/$slug"
if [[ ! -d "$outdir" ]]; then
  echo "[WARN] local out dir missing: $outdir ; skip push."
  exit 0
fi

REMOTE_BASE="$REMOTE_PREFIX"
# ensure remote folders exist (avoid 404)
rclone mkdir "$REMOTE_BASE" || true
rclone mkdir "${REMOTE_BASE}out" || true
rclone mkdir "${REMOTE_BASE}processed" || true
rclone mkdir "${REMOTE_BASE}failed" || true

# 上传最终产物
RCLONE_GLOBAL=(--tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}" --checkers "${SS_RCLONE_CHECKERS:-4}" --transfers "${SS_RCLONE_TRANSFERS:-2}" --fast-list --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}")
$DRY_RUN && RCLONE_GLOBAL+=(--dry-run)
rclone_cmd(){ echo "+ rclone ${RCLONE_GLOBAL[*]} $*" >&2; rclone "${RCLONE_GLOBAL[@]}" "$@"; }
rclone_cmd copy "$outdir" "${REMOTE_BASE}out/$slug" --checksum

# 判定成功/失败
pass=false
if [[ -f "$outdir/quality_report.json" ]]; then
  pass=true
fi
if $pass; then
  dest="processed"
else
  dest="failed"
  # 上传失败原因
  if [[ -f "$workdir/reason.txt" ]]; then
    rclone copy "$workdir/reason.txt" "${REMOTE_BASE}failed/${slug}.reason.txt" --checksum || true
  fi
fi

# 移动原始输入
if [[ -n "$remote_path" ]]; then
  rclone moveto "$remote_path" "${REMOTE_BASE}${dest}/${fname}" --checksum || true
fi
