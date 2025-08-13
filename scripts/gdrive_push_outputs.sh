#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

REMOTE_OUT="$SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/out"
REMOTE_ARCH="$SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/out-archives"
rclone mkdir "$REMOTE_OUT" >/dev/null 2>&1 || true
mkdir -p "$SS_INBOX/processed" "$SS_INBOX/failed"

slug_list=("$@")
if [ ${#slug_list[@]} -eq 0 ]; then
  mapfile -t slug_list < <(find "$SS_OUT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
fi

for slug in "${slug_list[@]}"; do
  outdir="$SS_OUT/$slug"
  workdir="$SS_WORK/$slug"
  [ -d "$outdir" ] || continue
  srcfile=$(cat "$workdir/.src" 2>/dev/null || echo '')
  rpath="${srcfile%%::*}"
  orig_name="${srcfile##*::}"
  local_in="$(find "$SS_INBOX" -maxdepth 1 -type f -name "$slug.*" | head -n1)"
  quality="$outdir/quality_report.json"
  pass=0
  if [ -f "$quality" ]; then
    pass=$(jq -r '.pass' "$quality" 2>/dev/null || echo 0)
  fi
  if [ "$pass" = "1" ] || [ "$pass" = "true" ]; then
    rclone mkdir "$REMOTE_OUT/$slug" >/dev/null 2>&1 || true
    rclone copy "$outdir" "$REMOTE_OUT/$slug" --checksum --fast-list
    if [ "${SS_ARCHIVE_OUT:-0}" = "1" ]; then
      ts=$(date -u +%Y%m%dT%H%M%SZ)
      rclone copy "$outdir" "$REMOTE_ARCH/$ts/$slug" --checksum --fast-list
    fi
    if [ -n "$local_in" ]; then
      mv "$local_in" "$SS_INBOX/processed/${orig_name:-$(basename "$local_in")}" 2>/dev/null || true
    fi
  else
    reason="processing failed"
    if [ -f "$quality" ]; then
      reason=$(jq -r '.length_drift_ratio' "$quality" 2>/dev/null)
    fi
    if [ -n "$local_in" ]; then
      mv "$local_in" "$SS_INBOX/failed/${orig_name:-$(basename "$local_in")}" 2>/dev/null || true
      echo "$reason" > "$SS_INBOX/failed/${orig_name:-$(basename "$local_in")}.reason.txt"
    fi
  fi
  rm -f "$workdir/.lock"
done

echo "[OK] pushed outputs"
