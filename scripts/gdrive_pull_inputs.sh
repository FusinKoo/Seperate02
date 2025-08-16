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

usage() {
  cat <<'USAGE'
Usage: scripts/gdrive_pull_inputs.sh [--dry-run]
Desc : 递归扫描远端 songs/ 并将新歌拉取至 ${SS_INBOX}；
       自动生成 slug、创建 .lock/.src。
Env  : SS_GDRIVE_REMOTE, SS_GDRIVE_ROOT, SS_INBOX, SS_WORK
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
    *) echo "[ERR] Unknown option: $1" >&2; usage; exit 2;;
  esac
done
ensure_vol_mount

if [ -z "${SS_GDRIVE_ROOT+x}" ]; then
  SS_GDRIVE_ROOT="Seperate02"
fi
_root="$SS_GDRIVE_ROOT"
[ "$_root" = "." ] && _root=""
REMOTE_PREFIX="${SS_GDRIVE_REMOTE}:${_root:+${_root}/}"
echo "[DBG] REMOTE_PREFIX=${REMOTE_PREFIX}" >&2
mkdir -p "$SS_INBOX" "$SS_WORK"

is_audio(){ case "${1,,}" in *.wav|*.flac|*.m4a|*.mp3) return 0;; *) return 1;; esac }

# 递归列出 songs 下的候选文件
RCLONE_GLOBAL=(--tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}" --checkers "${SS_RCLONE_CHECKERS:-4}" --transfers "${SS_RCLONE_TRANSFERS:-2}" --fast-list --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}")
$DRY_RUN && RCLONE_GLOBAL+=(--dry-run)
rclone_cmd(){ echo "+ rclone ${RCLONE_GLOBAL[*]} $*" >&2; rclone "${RCLONE_GLOBAL[@]}" "$@"; }
mapfile -t FILES < <(rclone_cmd lsf -R --files-only "${REMOTE_PREFIX}songs" || true)

for rel in "${FILES[@]:-}"; do
  [[ -n "$rel" ]] || continue
  src_remote="${REMOTE_PREFIX}songs/${rel}"
  fname="$(basename "$rel")"
  if ! is_audio "$fname"; then continue; fi

  # 拉取到临时路径
  tmp_local="${SS_INBOX}/.__tmp__${fname}"
  rclone_cmd copyto "$src_remote" "$tmp_local" --checksum || continue

  # 计算 slug（Unicode 保留 + 内容哈希）
  slug=$(python3 "$(dirname "$0")/slugify.py" --file "$tmp_local" --orig-name "$fname")
  ext=".${fname##*.}"
  local_final="${SS_INBOX}/${slug}${ext}"

  # 已存在同名且内容相同则跳过
  if [[ -f "$local_final" ]]; then
    echo "[SKIP] exists: $local_final"; rm -f "$tmp_local"; continue
  fi

  mv "$tmp_local" "$local_final"
  lockdir="${SS_WORK}/${slug}"
  mkdir -p "$lockdir"
  touch "$lockdir/.lock"
  cat > "$lockdir/.src" <<SRC
remote_path=${src_remote}
original_name=${fname}
SRC
  echo "[OK] pulled ${src_remote} -> ${local_final}"

done
