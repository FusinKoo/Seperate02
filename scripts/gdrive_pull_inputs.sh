#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

REMOTE="$SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/songs"
mkdir -p "$SS_INBOX" "$SS_WORK"
rclone mkdir "$REMOTE" >/dev/null 2>&1 || true

slugify(){
  local in="$1"
  echo "$in" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g' | sed -E 's/^_+|_+$//g'
}

declare -A seen
for ext in wav flac m4a mp3; do
  while read -r path; do
    [[ -z "$path" ]] && continue
    file="$(basename "$path")"
    slug="$(slugify "${file%.*}")"
    workdir="$SS_WORK/$slug"
    mkdir -p "$workdir"
    if [[ -n "${seen[$slug]:-}" ]]; then
      echo "$REMOTE/$path" >> "$workdir/.skipped"
      continue
    fi
    seen[$slug]=1
    lock="$workdir/.lock"
    : > "$lock"
    rclone copyto "$REMOTE/$path" "$SS_INBOX/$slug.$ext" --checksum --transfers 8 --checkers 8 --fast-list
    echo "$REMOTE/$path::$file" > "$workdir/.src"
    rm -f "$lock"
  done < <(rclone lsjson "$REMOTE" --files-only --recursive --include "*.$ext" --fast-list | jq -r '.[].Path')
done

echo "[OK] Pulled inputs to $SS_INBOX"
