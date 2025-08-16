#!/usr/bin/env bash
# common environment loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

# --- Base paths --------------------------------------------------------------
# 默认为 /workspace，可用 SS_BASE 或 SS_BASE_DIR 覆盖；仍兼容历史 /vol
: "${SS_BASE:=${SS_BASE_DIR:-/workspace}}"
export SS_BASE

# 统一派生目录
export SS_INBOX="$SS_BASE/inbox"
export SS_WORK="$SS_BASE/work"
export SS_OUT="$SS_BASE/out"
export SS_MODELS_DIR="$SS_BASE/models"
export SS_ASSETS_DIR="$SS_BASE/assets"
export SS_LOGS_DIR="$SS_BASE/logs"
export SS_WHEELS_DIR="$SS_BASE/wheels"
export SS_VENVS_DIR="$SS_BASE/venvs"

# venv 路径
export SS_UVR_VENV="$SS_VENVS_DIR/uvr"
export SS_RVC_VENV="$SS_VENVS_DIR/rvc"

# 创建目录（幂等）
mkdir -p "$SS_INBOX" "$SS_WORK" "$SS_OUT" "$SS_MODELS_DIR" "$SS_ASSETS_DIR" \
         "$SS_LOGS_DIR" "$SS_WHEELS_DIR" "$SS_VENVS_DIR"

# 兼容层：把 /vol/* 指到新的 SS_BASE（若可写）
if [ ! -e /vol ]; then mkdir -p /vol 2>/dev/null || true; fi
for d in inbox work out models assets logs wheels venvs rclone; do
  [ -e "/vol/$d" ] || ln -sfn "$SS_BASE/$d" "/vol/$d" 2>/dev/null || true
done

# RCLONE_CONFIG 自动探测：优先 env，其次 /workspace，再次 /vol
if [ -z "${RCLONE_CONFIG:-}" ]; then
  for c in "$SS_BASE/rclone/rclone.conf" "/vol/rclone/rclone.conf"; do
    if [ -f "$c" ]; then export RCLONE_CONFIG="$c"; break; fi
  done
fi

SS_GDRIVE_REMOTE=${SS_GDRIVE_REMOTE:-gdrive}
if [ -z "${SS_GDRIVE_ROOT+x}" ]; then
  export SS_GDRIVE_ROOT="Seperate02"
fi
if [ -z "${SS_USE_UV+x}" ]; then
  export SS_USE_UV=0
fi
SS_PARALLEL_JOBS=${SS_PARALLEL_JOBS:-4}
