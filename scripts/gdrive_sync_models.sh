#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

: "${SS_GDRIVE_REMOTE:=gdrive}"
if ! rclone listremotes 2>/dev/null | grep -q "^${SS_GDRIVE_REMOTE}:"; then
  echo "[ERR] rclone remote '${SS_GDRIVE_REMOTE}:' not found. Set SS_GDRIVE_REMOTE or configure rclone (RCLONE_CONFIG=$RCLONE_CONFIG)." >&2
  exit 2
fi

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
      --check  Only verify required models exist locally; do not sync
Examples:
  make setup-split
  bash scripts/gdrive_sync_models.sh
  bash scripts/run_one.sh <slug> ${SS_MODELS_DIR}/RVC/G_8200.pth ${SS_MODELS_DIR}/RVC/G_8200.index v2
USG
}
ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

CHECK_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --check) CHECK_ONLY=true; shift;;
    *) echo "[ERR] Unknown option: $1" >&2; usage; exit 2;;
  esac
done
ensure_vol_mount

if [ -z "${SS_GDRIVE_ROOT+x}" ]; then
  SS_GDRIVE_ROOT="Seperate02"
fi
_root="$SS_GDRIVE_ROOT"
[ "$_root" = "." ] && _root=""
REMOTE_PREFIX="${SS_GDRIVE_REMOTE}:${_root:+${_root}/}"
echo "[DBG] REMOTE_PREFIX=${REMOTE_PREFIX}" >&2

REMOTE_MODELS="${REMOTE_PREFIX}models"
REMOTE_ASSETS="${REMOTE_PREFIX}assets"
if ! rclone lsd "$REMOTE_ASSETS" >/dev/null 2>&1; then
  echo "[WARN] remote assets/ missing; fallback to models/" >&2
  REMOTE_ASSETS="$REMOTE_MODELS"
fi

LOCAL="$SS_MODELS_DIR"
mkdir -p "$LOCAL" "$SS_ASSETS_DIR" "$LOCAL/UVR" "$LOCAL/RVC"
RCLONE_OPTS=(--tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}" --checkers "${SS_RCLONE_CHECKERS:-4}" --transfers "${SS_RCLONE_TRANSFERS:-2}" --fast-list --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}")

# --- STRICT: Ensure dereverb model present ---
REQ_DEREV_MODEL="${SS_UVR_DEREVERB_MODEL:-Reverb_HQ_By_FoxJoy.onnx}"
LOCAL_DEREV="${SS_MODELS_DIR}/UVR/${REQ_DEREV_MODEL}"
REMOTE_DEREV="${REMOTE_PREFIX}models/UVR/${REQ_DEREV_MODEL}"

# try to fetch the exact file; ignore error here, hard check below
rclone copyto "$REMOTE_DEREV" "$LOCAL_DEREV" --checksum "${RCLONE_OPTS[@]}" >/dev/null 2>&1 || true

if [[ ! -f "$LOCAL_DEREV" ]]; then
  echo "[ERR] Missing dereverb model locally: $LOCAL_DEREV" >&2
  echo "[ERR] Please upload the file to: ${REMOTE_PREFIX}models/UVR/${REQ_DEREV_MODEL}" >&2
  echo "[ERR] Then re-run: bash scripts/gdrive_sync_models.sh" >&2
  exit 90
fi

# normal sync
if ! $CHECK_ONLY; then
  rclone sync "$REMOTE_MODELS" "$LOCAL" --checksum "${RCLONE_OPTS[@]}"
  rclone sync "$REMOTE_ASSETS" "$SS_ASSETS_DIR" --checksum "${RCLONE_OPTS[@]}"
fi
