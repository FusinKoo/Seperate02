#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

usage(){ cat <<USAGE
Usage:
  scripts/run_one.sh <input_file> <rvc_model.pth> <rvc.index> [v1|v2] [slug]
  scripts/run_one.sh <slug>  # requires SS_INBOX, SS_RVC_PTH and SS_RVC_INDEX
Examples:
  bash scripts/run_one.sh /vol/inbox/foo.wav /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index
  bash scripts/run_one.sh foo
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

mkdir -p "$SS_INBOX" "$SS_WORK" "$SS_OUT"

if [[ $# -ge 3 && -f "$1" ]]; then
  IN="$1"
  RVC_PTH="$2"
  RVC_INDEX="$3"
  RVC_VER="${4:-v2}"
  SLUG="${5:-$(basename "${IN%.*}")}"
elif [[ $# -eq 1 ]]; then
  SLUG="$1"
  for ext in wav flac m4a mp3; do
    if [[ -f "$SS_INBOX/$SLUG.$ext" ]]; then IN="$SS_INBOX/$SLUG.$ext"; break; fi
  done
  [[ -n "${IN:-}" ]] || { echo "[ERR] input $SLUG.* not found in $SS_INBOX" >&2; exit 1; }
  RVC_PTH="${SS_RVC_PTH:?SS_RVC_PTH not set}"
  RVC_INDEX="${SS_RVC_INDEX:?SS_RVC_INDEX not set}"
  RVC_VER="${SS_RVC_VER:-v2}"
else
  usage; exit 1
fi

LOCK="$SS_WORK/$SLUG/.lock"
if ! ( set -o noclobber; echo $$ > "$LOCK" ) 2>/dev/null; then
  echo "[WARN] $SLUG is locked" >&2
  exit 0
fi
trap 'rm -f "$LOCK"' EXIT

[[ -f "$IN" ]] || { echo "[ERR] missing input $IN" >&2; exit 1; }
[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC model not found: $RVC_PTH. Place G_8200.pth in $SS_MODELS_DIR/RVC/ or set SS_RVC_PTH" >&2; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC index not found: $RVC_INDEX. Place G_8200.index in $SS_MODELS_DIR/RVC/ or set SS_RVC_INDEX" >&2; exit 1; }
[[ "$RVC_VER" == v1 || "$RVC_VER" == v2 ]] || { echo "[ERR] RVC version must be v1 or v2" >&2; exit 1; }

RVC_TAG=$(basename "${RVC_PTH%.*}")
export SS_RVC_PTH="$RVC_PTH" SS_RVC_INDEX="$RVC_INDEX" SS_RVC_VER="$RVC_VER" SS_RVC_MODEL_TAG="$RVC_TAG"

TMP_TIME="$SS_WORK/$SLUG/steps_time.json"
mkdir -p "$SS_WORK/$SLUG"

start=$(date +%s); bash scripts/10_separate_inst.sh "$IN" "$SLUG"; end=$(date +%s); s1=$((end-start))
start=$(date +%s); bash scripts/20_extract_main.sh "$SLUG"; end=$(date +%s); s2=$((end-start))
start=$(date +%s); bash scripts/30_dereverb_denoise.sh "$SLUG"; end=$(date +%s); s3=$((end-start))
start=$(date +%s); bash scripts/40_rvc_convert.sh "$SLUG" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER"; end=$(date +%s); s4=$((end-start))

printf '{"sep_inst":%d,"extract_main":%d,"dereverb":%d,"rvc":%d}\n' "$s1" "$s2" "$s3" "$s4" > "$TMP_TIME"

python scripts/50_finalize_and_report.py --slug "$SLUG"
# optional:
# bash scripts/60_optional_mixdown.sh "$SLUG"

echo "[DONE] $SS_OUT/${SLUG}"
find "$SS_WORK/$SLUG" -mindepth 1 -not -name 'run.log' -not -name '.src' -delete
