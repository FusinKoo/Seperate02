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

if command -v audio-separator >/dev/null 2>&1; then
  ver=$(audio-separator --version 2>&1 | awk '{print $NF}')
  case "$ver" in
    0.35.2*) echo "audio-separator $ver";;
    *) echo "[WARN] audio-separator $ver (expected 0.35.2*)";;
  esac
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
echo "Expected ORT providers: CUDAExecutionProvider, CPUExecutionProvider"
providers=$(python -c 'import onnxruntime as ort; print(ort.get_available_providers())' 2>&1 || true)
echo "Actual ORT providers: $providers"
[[ "$providers" == *CUDAExecutionProvider* ]] || echo "[WRN] CUDAExecutionProvider not available"
mkdir -p "$SS_WORK"
echo "$providers" > "$SS_WORK/providers_snapshot.txt"
