#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: scripts/90_backup_gdrive.sh
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

SS_OUT=${SS_OUT:-/vol/out}
REMOTE_ROOT="gdrive:Seperate02/out"

rclone sync "$SS_OUT" "$REMOTE_ROOT" --transfers=8 --checkers=8 --fast-list --checksum --create-empty-src-dirs
TS=$(date +%Y%m%d-%H%M%S)
rclone copy "$SS_OUT" "gdrive:Seperate02/out-archives/${TS}" --transfers=8 --checkers=8 --fast-list --checksum --create-empty-src-dirs

echo "[OK] Backup done → $REMOTE_ROOT & out-archives/${TS}"
