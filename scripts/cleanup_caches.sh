#!/usr/bin/env bash
set -euo pipefail

: "${SS_CACHE_DIR:=/vol/.cache}"

# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

echo "[BEFORE]"
df -h / /vol "$SS_CACHE_DIR" 2>/dev/null || df -h

rm -rf "$HOME/.cache"/* "$SS_CACHE_DIR"/* /tmp/* 2>/dev/null || true
pip cache purge >/dev/null 2>&1 || true

echo "[AFTER]"
df -h / /vol "$SS_CACHE_DIR" 2>/dev/null || df -h
