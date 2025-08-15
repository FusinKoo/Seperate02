#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

usage(){
  cat <<'USAGE'
Usage: scripts/run_batch.sh <rvc_model.pth> <rvc.index> [v1|v2]
Desc : 基于 $SS_WORK/*/.lock 队列并发处理多首歌，每首日志写入 $SS_WORK/<slug>/run.log
Env  : SS_WORK, SS_PARALLEL_JOBS
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0;; esac

: "${SS_UVR_VENV:=/vol/venvs/uvr}"; : "${SS_RVC_VENV:=/vol/venvs/rvc}"
UVR_BIN="$SS_UVR_VENV/bin"; RVC_BIN="$SS_RVC_VENV/bin"
# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc
command -v "$UVR_BIN/audio-separator" >/dev/null || { echo "[ERR] audio-separator not found; run scripts/00_setup_env_split.sh"; exit 2; }

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

ensure_vol_mount
[[ -n "${1:-}" && -n "${2:-}" ]] || { usage; exit 2; }

SS_WORK=${SS_WORK:-/vol/work}
SS_PARALLEL_JOBS=${SS_PARALLEL_JOBS:-4}
RVC_PTH="$1"; RVC_INDEX="$2"; RVC_VER="${3:-v2}"
[[ -f "$RVC_PTH" ]] || { echo "[ERR] RVC .pth missing"; exit 1; }
[[ -f "$RVC_INDEX" ]] || { echo "[ERR] RVC .index missing"; exit 1; }

export RVC_PTH RVC_INDEX RVC_VER SS_WORK

# 可选：先同步模型 & 拉取新歌
if [[ -x scripts/gdrive_sync_models.sh ]]; then bash scripts/gdrive_sync_models.sh; fi
if [[ -x scripts/gdrive_pull_inputs.sh ]]; then bash scripts/gdrive_pull_inputs.sh; fi

# 队列：基于 .lock；若存在 .done 则跳过
mapfile -t SLUGS < <(find "$SS_WORK" -mindepth 2 -maxdepth 2 -type f -name .lock -printf '%h\n' | xargs -I{} basename {} | sort)

echo "[INFO] queued: ${#SLUGS[@]}"

# 并发执行（每首独立 run.log）
printf '%s\n' "${SLUGS[@]}" | xargs -I{} -P "$SS_PARALLEL_JOBS" bash -lc '
  slug="$1"; shift
  mkdir -p "$SS_WORK/$slug"
  log="$SS_WORK/$slug/run.log"
  echo "[BEGIN] $slug $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$log"
  if [[ -f "$SS_WORK/$slug/.done" ]]; then echo "[SKIP] done" | tee -a "$log"; exit 0; fi
  bash scripts/run_one.sh "$slug" "$RVC_PTH" "$RVC_INDEX" "$RVC_VER" >>"$log" 2>&1 && touch "$SS_WORK/$slug/.done"
  if [[ -x scripts/gdrive_push_outputs.sh ]]; then bash scripts/gdrive_push_outputs.sh "$slug" >>"$log" 2>&1 || true; fi
  echo "[END] $slug $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
' _ {}

