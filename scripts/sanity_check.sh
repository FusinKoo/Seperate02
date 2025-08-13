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
  audio-separator --env_info || true
else
  echo "[WARN] audio-separator not found; run scripts/00_setup_env.sh" >&2
fi

if [[ "${SS_FORCE_CPU:-0}" == 1 ]]; then
  echo "[WARN] SS_FORCE_CPU=1 → forcing CPU mode, performance will degrade" >&2
fi

if ORT_PROVIDERS=$(python - <<'PY' 2>/dev/null
import onnxruntime as ort
print(','.join(ort.get_available_providers()))
PY
); then
  echo "ORT providers: $ORT_PROVIDERS"
  if [[ "$ORT_PROVIDERS" != "CUDAExecutionProvider,CPUExecutionProvider" ]]; then
    echo "[ERR] unexpected providers order. expected CUDAExecutionProvider,CPUExecutionProvider" >&2
    exit 1
  fi
  export SS_ORT_PROVIDERS="$ORT_PROVIDERS"
else
  echo "[ERR] onnxruntime not found; run scripts/00_setup_env.sh" >&2
  exit 1
fi

for d in "$SS_INBOX" "$SS_WORK" "$SS_OUT" "$SS_MODELS_DIR" "$SS_ASSETS_DIR"; do
  [ -d "$d" ] || echo "[WARN] missing dir: $d"
done

echo "SS_INBOX=$SS_INBOX"; echo "SS_WORK=$SS_WORK"; echo "SS_OUT=$SS_OUT"
echo "SS_MODELS_DIR=$SS_MODELS_DIR"; echo "SS_ASSETS_DIR=$SS_ASSETS_DIR"
