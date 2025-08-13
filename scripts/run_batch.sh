#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SS_WORK=${SS_WORK:-/vol/work}
SS_PARALLEL_JOBS=${SS_PARALLEL_JOBS:-4}
RVC_PTH="$1"; RVC_INDEX="$2"; RVC_VER="${3:-v2}"
[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC .pth missing"; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC .index missing"; exit 1; }

export RVC_PTH RVC_INDEX RVC_VER

# 可选：先同步模型 & 拉取新歌
if [[ -x scripts/gdrive_sync_models.sh ]]; then bash scripts/gdrive_sync_models.sh; fi
if [[ -x scripts/gdrive_pull_inputs.sh ]]; then bash scripts/gdrive_pull_inputs.sh; fi

# 队列：基于 .lock；若存在 .done 则跳过
mapfile -t SLUGS < <(find "$SS_WORK" -mindepth 2 -maxdepth 2 -type f -name .lock -printf '%h\n' | xargs -I{} basename {} | sort)

echo "[INFO] queued: ${#SLUGS[@]}"

printf '%s\n' "${SLUGS[@]}" | xargs -I{} -P "$SS_PARALLEL_JOBS" bash -lc '
  slug="$1"; shift
  if [[ -f "$SS_WORK/$slug/.done" ]]; then echo "[SKIP] $slug done"; exit 0; fi
  bash scripts/run_one.sh "$slug" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER" && touch "$SS_WORK/$slug/.done"
  if [[ -x scripts/gdrive_push_outputs.sh ]]; then bash scripts/gdrive_push_outputs.sh "$slug" || true; fi
' _ {}
