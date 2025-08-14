#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR=${SS_CACHE_DIR:-/vol/.cache}

echo "[BEFORE]"
df -h / /vol "$CACHE_DIR"

rm -rf "$HOME/.cache" "$CACHE_DIR/pip" "$CACHE_DIR/huggingface" "$CACHE_DIR/torch" /root/.cache/pip 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

echo "[AFTER]"
df -h / /vol "$CACHE_DIR"
