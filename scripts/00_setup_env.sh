#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: bash scripts/00_setup_env.sh
Installs system packages, python deps and prepares directories.
USAGE
}
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then usage; exit 0; fi

sudo apt-get update
sudo apt-get install -y ffmpeg git curl unzip rclone python3-venv

cd "$(dirname "$0")/.."

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools

if [[ -f requirements-locked.txt ]]; then
  pip install -r requirements-locked.txt --index-url https://download.pytorch.org/whl/cu121
else
  pip install "audio-separator[gpu]==0.35.2" \
              onnxruntime-gpu==1.19.2 \
              torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
              --index-url https://download.pytorch.org/whl/cu121
  pip install numpy==1.26.4 librosa==0.10.2.post1 soundfile==0.12.1 resampy==0.4.3 \
              pyloudnorm==0.1.1 tqdm==4.66.4 click==8.1.7 python-dotenv==1.0.1 rich==13.7.1 \
              jinja2==3.1.4 pydub==0.25.1
  pip install rvc-python==0.1.5
fi

SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}
SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}

mkdir -p "$SS_INBOX" "$SS_WORK" "$SS_OUT" "$SS_MODELS_DIR/UVR" "$SS_MODELS_DIR/RVC" "$SS_ASSETS_DIR"

[ -f "$SS_ASSETS_DIR/hubert_base.pt" ] || \
  curl -L -o "$SS_ASSETS_DIR/hubert_base.pt" https://dl.fbaipublicfiles.com/hubert/hubert_base_ls960.pt
[ -f "$SS_ASSETS_DIR/rmvpe.onnx" ] || \
  curl -L -o "$SS_ASSETS_DIR/rmvpe.onnx" https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.onnx

if ! audio-separator --env_info | grep -q "CUDAExecutionProvider"; then
  echo "[ERR] CUDAExecutionProvider not detected. Please check CUDA drivers/ORT installation." >&2
  exit 1
fi

echo "[OK] setup done"
