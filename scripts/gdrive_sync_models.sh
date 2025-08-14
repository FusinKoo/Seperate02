#!/usr/bin/env bash
set -euo pipefail

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

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/env.sh" ]]; then
  echo "[FATAL] Missing $SCRIPT_DIR/env.sh" >&2
  exit 2
fi
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

REMOTE="$SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/models"
LOCAL="$SS_MODELS_DIR"
mkdir -p "$LOCAL" "$SS_ASSETS_DIR" "$LOCAL/UVR" "$LOCAL/RVC"
rclone mkdir "$REMOTE" >/dev/null 2>&1 || true

# Sync all model files
rclone copy "$REMOTE" "$LOCAL" --checksum --transfers 8 --checkers 8 --fast-list

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

missing=()
[[ -f "$LOCAL/UVR/UVR-MDX-NET-Inst_HQ_3.onnx" ]] || missing+=("UVR-MDX-NET-Inst_HQ_3.onnx")
[[ -f "$LOCAL/UVR/Kim_Vocal_2.onnx" ]] || missing+=("Kim_Vocal_2.onnx")
[[ -f "$LOCAL/UVR/Reverb_HQ_By_FoxJoy.onnx" ]] || missing+=("Reverb_HQ_By_FoxJoy.onnx")
[[ -f "$LOCAL/RVC/G_8200.pth" ]] || missing+=("G_8200.pth")
[[ -f "$LOCAL/RVC/G_8200.index" ]] || missing+=("G_8200.index")
[[ -f "$SS_ASSETS_DIR/hubert_base.pt" ]] || missing+=("hubert_base.pt")
[[ -f "$SS_ASSETS_DIR/rmvpe.onnx" ]] || missing+=("rmvpe.onnx")

if [ ${#missing[@]} -ne 0 ]; then
  echo "[ERR] Missing models: ${missing[*]}" >&2
  echo "[ERR] Please upload missing files to $SS_GDRIVE_REMOTE:$SS_GDRIVE_ROOT/models/" >&2
  exit 1
fi

echo "[OK] Models synced to $LOCAL and $SS_ASSETS_DIR"
