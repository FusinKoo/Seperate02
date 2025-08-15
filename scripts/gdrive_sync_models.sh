#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
      --check  Only verify required assets
Examples:
  bash scripts/gdrive_sync_models.sh
USG
}

CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0;;
    --check) CHECK_ONLY=true;;
  esac
done

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

ensure_vol_mount

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

REMOTE="$SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/models"
LOCAL="$SS_MODELS_DIR"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/manifest"
MANIFEST="$MANIFEST_DIR/models_required.txt"
mkdir -p "$LOCAL" "$SS_ASSETS_DIR" "$LOCAL/UVR" "$LOCAL/RVC"
rclone mkdir "$REMOTE" >/dev/null 2>&1 || true

RCLONE_OPTS=(--checksum --fast-list --transfers "${SS_RCLONE_TRANSFERS:-4}" --checkers "${SS_RCLONE_CHECKERS:-8}" --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}" --tpslimit "${SS_RCLONE_TPS:-4}" --tpslimit-burst "${SS_RCLONE_TPS:-4}")

check_required(){
  local missing=()
  while read -r rel; do
    [[ -z "$rel" || "$rel" =~ ^# ]] && continue
    local path
    if [[ "$rel" == assets/* ]]; then
      path="$SS_ASSETS_DIR/${rel#assets/}"
    else
      path="$LOCAL/$rel"
    fi
    [[ -f "$path" ]] || missing+=("$rel")
  done < "$MANIFEST"
  if [ ${#missing[@]} -eq 0 ]; then
    echo "[OK] all required assets present"
    return 0
  fi
  echo "[ERR] missing assets: ${missing[*]}" >&2
  return 3
}

if $CHECK_ONLY; then
  check_required
  exit $?
fi

# Sync all model files
rclone copy "$REMOTE" "$LOCAL" "${RCLONE_OPTS[@]}"

# relocate expected files
move_if_found(){
  local name="$1" dest="$2"
  local found
  found=$(find "$LOCAL" -type f -name "$name" | head -n1 || true)
  if [ -n "$found" ]; then
    mkdir -p "$(dirname "$dest")"
    mv -f "$found" "$dest"
  fi
}

move_if_found "UVR-MDX-NET-Inst_HQ_3.onnx" "$LOCAL/UVR/UVR-MDX-NET-Inst_HQ_3.onnx"
move_if_found "Kim_Vocal_2.onnx" "$LOCAL/UVR/Kim_Vocal_2.onnx"
move_if_found "Reverb_HQ_By_FoxJoy.onnx" "$LOCAL/UVR/Reverb_HQ_By_FoxJoy.onnx"
move_if_found "G_8200.pth" "$LOCAL/RVC/G_8200.pth"
move_if_found "G_8200.index" "$LOCAL/RVC/G_8200.index"
move_if_found "hubert_base.pt" "$SS_ASSETS_DIR/hubert_base.pt"
move_if_found "rmvpe.onnx" "$SS_ASSETS_DIR/rmvpe.onnx"

if ! check_required; then
  echo "[ERR] Please upload missing files to $SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/models/" >&2
  exit 1
fi

echo "[OK] Models synced to $LOCAL and $SS_ASSETS_DIR"

