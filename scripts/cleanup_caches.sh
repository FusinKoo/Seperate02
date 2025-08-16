#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
Examples:
  make setup-split
  bash scripts/gdrive_sync_models.sh
  bash scripts/run_one.sh <slug> ${SS_MODELS_DIR}/RVC/G_8200.pth ${SS_MODELS_DIR}/RVC/G_8200.index v2
USG
}
case "${1:-}" in -h|--help) usage; exit 0;; esac

: "${SS_CACHE_DIR:=/vol/.cache}"

# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

echo "[BEFORE]"
df -h / /vol "$SS_CACHE_DIR" 2>/dev/null || df -h

rm -rf "$HOME/.cache"/* "$SS_CACHE_DIR"/* /tmp/* 2>/dev/null || true
pip cache purge >/dev/null 2>&1 || true

echo "[AFTER]"
df -h / /vol "$SS_CACHE_DIR" 2>/dev/null || df -h
