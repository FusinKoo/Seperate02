#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USG
Usage: $(basename "$0") [options]
Options:
  -h, --help   Show this help and exit
Examples:
  make setup-split
  bash scripts/gdrive_sync_models.sh
  bash scripts/run_one.sh <slug> /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index v2

Ensure /vol is mounted before running. In Runpod UI:
  Stop Pod -> Attach Network Volume -> Mount path=/vol -> Start
USG
}
: "${SS_UVR_VENV:=/vol/venvs/uvr}"
: "${SS_RVC_VENV:=/vol/venvs/rvc}"
: "${SS_CACHE_DIR:=/vol/.cache}"

# === add near the top (pip cache, wheel vars, signature helpers) ===
sig_lock_sha(){ sha256sum requirements-locked.txt 2>/dev/null | awk '{print $1}'; }
mk_profile(){
  python3 - <<'PY'
import sys,platform,os
cuda=os.environ.get("SS_CUDA_TAG","cu124")
print(f"cp{sys.version_info.major}{sys.version_info.minor}-{cuda}-{platform.system().lower()}_{platform.machine()}")
PY
}
PROFILE="${SS_WHEEL_PROFILE:-$(mk_profile)}"
WHEELBASE="${SS_WHEELHOUSE:-/vol/wheels}/${PROFILE}"
WH_UVR="${WHEELBASE}/uvr"; WH_RVC="${WHEELBASE}/rvc"; WH_LOCK="${WHEELBASE}/lock"

if [[ "${SS_PIP_CACHE:-1}" -eq 1 ]]; then
  export PIP_CACHE_DIR="${SS_CACHE_DIR:-/vol/.cache}/pip"
  mkdir -p "$PIP_CACHE_DIR"
fi

ensure_vol_mount() {
  if ! mount | grep -Eq '[[:space:]]/vol[[:space:]]'; then
    echo "[ERR] /vol is not mounted. Please attach Network Volume at /vol in Runpod, then re-run." >&2
    echo "HINT: Stop Pod → Attach Network Volume → Mount path=/vol → Start" >&2
    exit 32
  fi
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --locked)
    pip install -r requirements-locked.txt --require-hashes
    exit 0
    ;;
esac
ensure_vol_mount

if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "[WARN] ffmpeg not found. Install with: apt-get update && apt-get install -y --no-install-recommends ffmpeg" >&2
  else
    echo "[WARN] ffmpeg not found and apt-get unavailable; please install ffmpeg manually." >&2
  fi
else
  ffmpeg -version | head -n 1
fi

# ensure string for rg checks
# requires $SS_UVR_VENV/bin/audio-separator and $SS_RVC_VENV/bin/rvc

mkdir -p "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR"

export HF_HOME="$SS_CACHE_DIR/hf"
export TRANSFORMERS_CACHE="$SS_CACHE_DIR/hf"
export TORCH_HOME="$SS_CACHE_DIR/torch"
export TMPDIR=/vol/tmp
mkdir -p "$HF_HOME" "$TORCH_HOME" "$TMPDIR"

write_sig(){
  local venv="$1"
  local sig="${venv}/.sig"
  {
    echo "profile=$PROFILE"
    echo "py=$("$venv/bin/python" -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    echo "lock_sha=$(sig_lock_sha)"
    date -u +"utc=%Y-%m-%dT%H:%M:%SZ"
  } > "$sig"
}

need_rebuild(){
  local venv="$1"; local sig="${venv}/.sig"
  [[ -d "$venv" && -f "$sig" ]] || return 0
  grep -q "profile=$PROFILE" "$sig" || return 0
  if [[ -f requirements-locked.txt ]]; then
    local cur=$(sig_lock_sha); grep -q "lock_sha=$cur" "$sig" || return 0
  fi
  return 1  # no rebuild needed
}

install_with_fallback(){
  local VENV_BIN="$1"; shift
  local REQ_FILE="$1"; shift
  local WH_DIRS=("$@")

  # 1) wheelhouse 优先
  local FL=()
  for d in "${WH_DIRS[@]}"; do [[ -d "$d" ]] && FL+=( --find-links "$d" ); done
  if (( ${#FL[@]} )); then
    if "$VENV_BIN/pip" install --no-index "${FL[@]}" -r "$REQ_FILE"; then
      return 0
    fi
  fi

  # 2) 自动从 GDrive 拉取再尝试
  if [[ "${SS_PREFER_WHEELS:-1}" -eq 1 && "${SS_WHEELS_PULL_ON_MISS:-1}" -eq 1 ]]; then
    bash scripts/wheels_pull.sh || true
    FL=()
    for d in "${WH_DIRS[@]}"; do [[ -d "$d" ]] && FL+=( --find-links "$d" ); done
    if (( ${#FL[@]} )); then
      if "$VENV_BIN/pip" install --no-index "${FL[@]}" -r "$REQ_FILE"; then
        return 0
      fi
    fi
  fi

  # 3) 回源（带缓存）
  "$VENV_BIN/pip" install -r "$REQ_FILE"
}

# ====== UVR venv ======
if need_rebuild "$SS_UVR_VENV"; then
  python3 -m venv "$SS_UVR_VENV"
  "$SS_UVR_VENV/bin/pip" install -U pip wheel setuptools
  install_with_fallback "$SS_UVR_VENV/bin" requirements-uvr.txt "$WH_UVR"
  "$SS_UVR_VENV/bin/pip" cache purge || true
  write_sig "$SS_UVR_VENV"
else
  echo "[OK] reuse UVR venv ($SS_UVR_VENV)"
fi

# ====== RVC venv ======
if need_rebuild "$SS_RVC_VENV"; then
  "$SS_RVC_VENV/bin/python" -m venv "$SS_RVC_VENV" || python3 -m venv "$SS_RVC_VENV"
  "$SS_RVC_VENV/bin/python" -m pip install -U "pip<24.1" "setuptools<70" wheel
  "$SS_RVC_VENV/bin/pip" install "numpy==1.23.5"
  "$SS_RVC_VENV/bin/pip" install --index-url https://download.pytorch.org/whl/${SS_CUDA_TAG:-cu124} \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0
  install_with_fallback "$SS_RVC_VENV/bin" requirements-rvc.txt "$WH_RVC"
  "$SS_RVC_VENV/bin/pip" cache purge || true
  write_sig "$SS_RVC_VENV"
else
  echo "[OK] reuse RVC venv ($SS_RVC_VENV)"
fi

UVR_BIN="$SS_UVR_VENV/bin/audio-separator"
RVC_BIN="$SS_RVC_VENV/bin/rvc"
command -v "$UVR_BIN" >/dev/null && echo "[OK] UVR binary: $UVR_BIN ($("$UVR_BIN" --version))"
command -v "$RVC_BIN" >/dev/null && echo "[OK] RVC binary: $RVC_BIN ($("$RVC_BIN" --version 2>/dev/null || echo unknown))"
df -h / /vol "$SS_UVR_VENV" "$SS_RVC_VENV" "$SS_CACHE_DIR" 2>/dev/null || df -h

echo "[OK] UVR venv: $SS_UVR_VENV"
echo "[OK] RVC venv: $SS_RVC_VENV"
