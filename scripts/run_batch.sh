#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: scripts/run_batch.sh <rvc_model.pth> <rvc.index> [v1|v2]
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

RVC_PTH="${1:-}"
RVC_INDEX="${2:-}"
RVC_VER="${3:-v2}"
if [[ -z "$RVC_PTH" || -z "$RVC_INDEX" ]]; then
  usage; echo "[ERR] require rvc_model.pth and rvc.index" >&2; exit 1
fi
PARALLEL="${SS_PARALLEL_JOBS:-4}"

SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}

[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC model not found: $RVC_PTH. Place G_8200.pth in $SS_MODELS_DIR/RVC/ or set SS_RVC_PTH" >&2; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC index not found: $RVC_INDEX. Place G_8200.index in $SS_MODELS_DIR/RVC/ or set SS_RVC_INDEX" >&2; exit 1; }

declare -A seen
for ext in wav flac m4a mp3; do
  while IFS= read -r f; do
    slug=$(basename "${f%.*}")
    [[ -n "${seen[$slug]:-}" ]] && continue
    seen[$slug]=1
    echo "$f::$slug"
  done < <(find "$SS_INBOX" -maxdepth 1 -type f -iname "*.$ext" | sort)
done |
while IFS='::' read -r f slug; do
  mkdir -p "$SS_WORK/$slug"
  echo "bash scripts/run_one.sh \"$f\" \"$RVC_PTH\" \"$RVC_INDEX\" $RVC_VER \"$slug\" >\"$SS_WORK/$slug/run.log\" 2>&1"
done | xargs -I{} -P "$PARALLEL" bash -lc "{} || true"
