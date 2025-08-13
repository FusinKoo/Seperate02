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

mkdir -p "$SS_INBOX" "$SS_WORK" "$SS_OUT"

bash "$SCRIPT_DIR/gdrive_sync_models.sh"
bash "$SCRIPT_DIR/gdrive_pull_inputs.sh"

[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC model not found: $RVC_PTH. Place G_8200.pth in $SS_MODELS_DIR/RVC/" >&2; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC index not found: $RVC_INDEX. Place G_8200.index in $SS_MODELS_DIR/RVC/" >&2; exit 1; }

declare -A seen
slugs=()
for ext in wav flac m4a mp3; do
  while IFS= read -r f; do
    slug=$(basename "${f%.*}")
    [[ -n "${seen[$slug]:-}" ]] && continue
    seen[$slug]=1
    slugs+=("$slug::$f")
  done < <(find "$SS_INBOX" -maxdepth 1 -type f -iname "*.$ext" | sort)
done

processed=()
for item in "${slugs[@]}"; do
  slug="${item%%::*}"
  f="${item##*::}"
  mkdir -p "$SS_WORK/$slug"
  if bash "$SCRIPT_DIR/run_one.sh" "$f" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER" "$slug" >"$SS_WORK/$slug/run.log" 2>&1; then
    processed+=("$slug")
  fi
done

printf '%s\n' "${processed[@]}" | xargs -I{} -P "$SS_PARALLEL_JOBS" bash "$SCRIPT_DIR/gdrive_push_outputs.sh" {}
