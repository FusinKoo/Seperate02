#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: bash scripts/sanity_check.sh
Checks GPU/ORT providers and directory availability.
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}
SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}

command -v nvidia-smi >/dev/null && nvidia-smi || echo "[WARN] nvidia-smi not found; install NVIDIA drivers" >&2

if command -v audio-separator >/dev/null; then
  ver=$(audio-separator --version 2>&1)
  echo "audio-separator $ver"
  [[ $ver == 0.35.2* ]] || echo "[WARN] expected audio-separator 0.35.2" >&2
else
  echo "[WARN] audio-separator not found; run scripts/00_setup_env_split.sh" >&2
fi

if command -v ffmpeg >/dev/null; then
  ffmpeg -version | head -n 1
else
  echo "[WARN] ffmpeg not found" >&2
fi

if [[ "${SS_FORCE_CPU:-0}" == 1 ]]; then
  echo "[WARN] SS_FORCE_CPU=1 → forcing CPU mode, performance will degrade" >&2
fi

for d in "$SS_INBOX" "$SS_WORK" "$SS_OUT" "$SS_MODELS_DIR" "$SS_ASSETS_DIR"; do
  [ -d "$d" ] || echo "[WARN] missing dir: $d"
done

echo "SS_INBOX=$SS_INBOX"; echo "SS_WORK=$SS_WORK"; echo "SS_OUT=$SS_OUT"
echo "SS_MODELS_DIR=$SS_MODELS_DIR"; echo "SS_ASSETS_DIR=$SS_ASSETS_DIR"

if mountpoint -q /vol; then
  df -h /vol
  echo "Top usage in /vol:"; du -h --max-depth=1 /vol | sort -hr | head -n 10
else
  echo "[WARN] /vol is not a mountpoint" >&2
fi

# ORT providers 检查
python3 - <<'PY'
import json, sys
try:
    import onnxruntime as ort
    prov = ort.get_available_providers()
    print("ORT providers:", prov)
    wants = ['CUDAExecutionProvider', 'CPUExecutionProvider']
    if prov[:2] == wants:
        print('[OK] Provider order CUDA→CPU confirmed')
    elif 'CUDAExecutionProvider' in prov and 'CPUExecutionProvider' in prov:
        print('[WARN] Providers present but order != CUDA→CPU (actual:', prov, ')')
    elif 'CPUExecutionProvider' in prov:
        print('[WARN] CUDAExecutionProvider missing, CPU-only mode (actual:', prov, ')')
    else:
        print('[ERR] Missing CUDA/CPU providers, actual:', prov)
        sys.exit(3)
except Exception as e:
    print('[ERR] onnxruntime not available:', e)
    sys.exit(2)
PY
