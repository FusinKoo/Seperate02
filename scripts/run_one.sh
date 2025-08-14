#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
export LC_ALL=C.UTF-8

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}
ensure_vol_mount

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
Examples:
  make setup-split
  bash scripts/gdrive_sync_models.sh
  bash scripts/run_one.sh <slug> /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index v2
USG
}
case "${1:-}" in -h|--help) usage; exit 0;; esac

# env defaults
SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}

: "${SS_UVR_VENV:=/vol/venvs/uvr}"; : "${SS_RVC_VENV:=/vol/venvs/rvc}"
UVR_BIN="$SS_UVR_VENV/bin"; RVC_BIN="$SS_RVC_VENV/bin"
# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc
command -v "$UVR_BIN/audio-separator" >/dev/null || { echo "[ERR] audio-separator not found; run scripts/00_setup_env_split.sh"; exit 2; }

IN=${1:-}
RVC_PTH=${2:-${SS_RVC_PTH:-}}
RVC_INDEX=${3:-${SS_RVC_INDEX:-}}
RVC_VER=${4:-${SS_RVC_VER:-v2}}

# 预声明，令 Shellcheck/ set -u 满意
slug=""
path=""
local_inbox_path=""

kv_get() { # $1=key $2=file
  awk -F'=' -v k="$1" '$1==k{sub(/^[^=]*=/,"" ); print; exit}' "$2"
}

if [[ -z "$IN" ]]; then
  usage
  exit 2
fi

if [[ "$IN" == */* ]]; then
  path="$IN"
  slug="$(basename "${path%.*}")"
else
  slug="$IN"
  srcf="$SS_WORK/$slug/.src"
  [[ -f "$srcf" ]] || { echo "[ERR] $srcf not found" >&2; exit 1; }
  local_inbox_path="$(kv_get local_inbox_path "$srcf")"
  [[ -n "$local_inbox_path" ]] || { echo "[ERR] $srcf missing local_inbox_path" >&2; exit 1; }
  path="$local_inbox_path"
fi

[[ -f "$path" ]] || { echo "[ERR] input not found: $path" >&2; exit 1; }
[[ -n "$RVC_PTH" && -f "$RVC_PTH" ]] || { echo "[ERR] RVC .pth missing" >&2; exit 1; }
[[ -n "$RVC_INDEX" && -f "$RVC_INDEX" ]] || { echo "[ERR] RVC .index missing" >&2; exit 1; }

# 串行步骤
bash scripts/10_separate_inst.sh "$path" "$slug"
bash scripts/20_extract_main.sh "$slug"
bash scripts/30_dereverb_denoise.sh "$slug"
bash scripts/40_rvc_convert.sh "$slug" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER"
"$SS_UVR_VENV/bin/python" scripts/50_finalize_and_report.py --slug "$slug"
# 可选：
# bash scripts/60_optional_mixdown.sh "$slug"

echo "[DONE] $slug → $SS_OUT/$slug"
