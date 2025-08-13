#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y ffmpeg git curl unzip rclone python3-venv

# 进入仓库根目录（确保当前路径正确）
cd "$(dirname "$0")/.."

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip wheel setuptools

# ---- Python 依赖（GPU/ORT/Torch 固定版本） ----
pip install "audio-separator[gpu]==0.35.2" \
            onnxruntime-gpu==1.19.2 \
            torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
            --index-url https://download.pytorch.org/whl/cu121

pip install numpy==1.26.4 librosa==0.10.2.post1 soundfile==0.12.1 resampy==0.4.3 \
            pyloudnorm==0.1.1 tqdm==4.66.4 click==8.1.7 python-dotenv==1.0.1 rich==13.7.1 \
            jinja2==3.1.4 pydub==0.25.1

# RVC 推理封装（从 PyPI 安装 rvc-python；若版本更新，Agent 可选同系最新稳定版）
pip install rvc-python==0.1.5

# 目录就绪
mkdir -p /vol/{inbox,work,out} /vol/models/{UVR,RVC} /vol/assets

# RVC 依赖（若不存在则下载）
[ -f /vol/assets/hubert_base.pt ] || \
  curl -L -o /vol/assets/hubert_base.pt https://dl.fbaipublicfiles.com/hubert/hubert_base_ls960.pt
[ -f /vol/assets/rmvpe.onnx ] || \
  curl -L -o /vol/assets/rmvpe.onnx https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.onnx

# ORT GPU Provider 自检（失败则安装 nightly 兜底）
if ! audio-separator --env_info | grep -q "CUDAExecutionProvider"; then
  echo "[WARN] CUDAExecutionProvider not detected. Installing ORT nightly..."
  pip install --force-reinstall --no-cache-dir ort-nightly-gpu \
    --index-url=https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-12-nightly/pypi/simple/
  audio-separator --env_info
fi

echo "[OK] setup done"
