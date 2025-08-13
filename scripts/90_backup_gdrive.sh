#!/usr/bin/env bash
set -euo pipefail

REMOTE_ROOT="gdrive:Seperate02/out"

# 首次需已完成：rclone config 交互创建名为 gdrive 的远端（drive 类型）

rclone sync /vol/out "$REMOTE_ROOT" --transfers=8 --checkers=8 --fast-list --checksum --create-empty-src-dirs
TS=$(date +%Y%m%d-%H%M%S)
rclone copy /vol/out "gdrive:Seperate02/out-archives/${TS}" --transfers=8 --checkers=8 --fast-list --checksum --create-empty-src-dirs

echo "[OK] Backup done → $REMOTE_ROOT & out-archives/${TS}"
