#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage:
  scripts/run_one.sh <input_file> <rvc_model.pth> [index] [v1|v2] [slug]
  scripts/run_one.sh <slug>  # requires SS_INBOX and SS_RVC_PTH
Examples:
  bash scripts/run_one.sh /vol/inbox/foo.wav /vol/models/RVC/G.pth
  bash scripts/run_one.sh foo
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}
SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}

if [[ $# -ge 2 && -f "$1" ]]; then
  IN="$1"
  RVC_PTH="$2"
  RVC_INDEX="${3:-}"
  RVC_VER="${4:-v2}"
  SLUG="${5:-$(basename "${IN%.*}")}"
elif [[ $# -eq 1 ]]; then
  SLUG="$1"
  for ext in wav flac m4a mp3; do
    if [[ -f "$SS_INBOX/$SLUG.$ext" ]]; then IN="$SS_INBOX/$SLUG.$ext"; break; fi
  done
  [[ -n "${IN:-}" ]] || { echo "[ERR] input $SLUG.* not found in $SS_INBOX" >&2; exit 1; }
  RVC_PTH="${SS_RVC_PTH:?SS_RVC_PTH not set}"
  RVC_INDEX="${SS_RVC_INDEX:-}"
  RVC_VER="${SS_RVC_VER:-v2}"
else
  usage; exit 1
fi

[[ -f "$IN" ]] || { echo "[ERR] missing input $IN" >&2; exit 1; }
[[ -f "$RVC_PTH" ]] || { echo "[ERR] missing RVC model $RVC_PTH" >&2; exit 1; }
[[ -z "$RVC_INDEX" || -f "$RVC_INDEX" ]] || { echo "[ERR] bad RVC index $RVC_INDEX" >&2; exit 1; }
[[ "$RVC_VER" == v1 || "$RVC_VER" == v2 ]] || { echo "[ERR] RVC version must be v1 or v2" >&2; exit 1; }

export SS_RVC_PTH="$RVC_PTH" SS_RVC_INDEX="$RVC_INDEX" SS_RVC_VER="$RVC_VER"

bash scripts/10_separate_inst.sh "$IN" "$SLUG"
bash scripts/20_extract_main.sh "$SLUG"
bash scripts/30_dereverb_denoise.sh "$SLUG"
bash scripts/40_rvc_convert.sh "$SLUG" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER"
python scripts/50_finalize_and_report.py --slug "$SLUG"
# optional:
# bash scripts/60_optional_mixdown.sh "$SLUG"

echo "[DONE] $SS_OUT/${SLUG}"
