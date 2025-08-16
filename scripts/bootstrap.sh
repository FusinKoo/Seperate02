#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# 0) 基础环境变量
source scripts/env.sh

# 1) 安装 micromamba（幂等）
make env

# 2) 建 runner 并安装 snakemake（幂等）
make setup

# 3) 建 UVR/RVC 两个 venv（幂等）
make setup-split

# 4) 自检（干跑 DAG + ORT providers）
make snk-dry
make sanity

echo "[OK] bootstrap finished."
