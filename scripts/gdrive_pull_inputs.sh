#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
export LC_ALL=C.UTF-8

usage() {
  cat <<'USAGE'
Usage: scripts/gdrive_pull_inputs.sh [--dry-run]
Desc : 递归扫描 ${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/songs/ 并将新歌拉取至 ${SS_INBOX}；
       自动生成 slug、创建 .lock/.src。无需参数。
Env  : SS_GDRIVE_REMOTE, SS_GDRIVE_ROOT, SS_INBOX, SS_WORK
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
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0;;
    --dry-run) DRY_RUN="--dry-run";;
  esac
done
ensure_vol_mount

# vars & dirs
SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_GDRIVE_REMOTE=${SS_GDRIVE_REMOTE:-gdrive}
SS_GDRIVE_ROOT=${SS_GDRIVE_ROOT:-Seperate02}
mkdir -p "$SS_INBOX" "$SS_WORK"

is_audio(){ case "${1,,}" in *.wav|*.flac|*.m4a|*.mp3) return 0;; *) return 1;; esac }

# 递归列出 songs 下的候选文件
RCLONE_OPTS=(--checksum --fast-list --transfers "${SS_RCLONE_TRANSFERS:-4}" --checkers "${SS_RCLONE_CHECKERS:-8}" --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}" --tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}")
mapfile -t FILES < <(rclone lsf -R --files-only "${RCLONE_OPTS[@]}" "${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/songs" || true)

for rel in "${FILES[@]:-}"; do
  [[ -n "$rel" ]] || continue
  src_remote="${SS_GDRIVE_REMOTE}:${SS_GDRIVE_ROOT}/songs/${rel}"
  fname="$(basename "$rel")"
  if ! is_audio "$fname"; then continue; fi

  # 拉取到临时路径
  tmp_local="${SS_INBOX}/.__tmp__${fname}"
  cmd=(rclone copyto "$src_remote" "$tmp_local" "${RCLONE_OPTS[@]}")
  [[ -n "$DRY_RUN" ]] && cmd+=("$DRY_RUN")
  echo "+ ${cmd[*]}"
  "${cmd[@]}" || continue

  # 计算 slug（Unicode 保留 + 内容哈希）
  slug=$(python3 "$(dirname "$0")/slugify.py" --file "$tmp_local" --orig-name "$fname")
  ext=".${fname##*.}"
  local_final="${SS_INBOX}/${slug}${ext}"

  # 已存在同名且内容相同则跳过
  if [[ -f "$local_final" ]]; then
    echo "[SKIP] exists: $local_final"; rm -f "$tmp_local"; continue
  fi

  mv -f "$tmp_local" "$local_final"

  # 工作目录与标记
  workdir="${SS_WORK}/${slug}"; mkdir -p "$workdir"
  : >"$workdir/.lock"  # 加锁
  {
    echo "remote_path=$src_remote"
    echo "original_name=$fname"
    echo "ext=$ext"
    echo "slug=$slug"
    echo "local_inbox_path=$local_final"
    echo "ts_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$workdir/.src"

  echo "[PULLED] $fname → $local_final (slug=$slug)"

done

echo "[DONE] gdrive_pull_inputs"
