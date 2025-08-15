# Seperate02

## Seperate02 — CLS（契约锁定串行流水线）

**当前版本：契约 v3**（详见 [docs/contract_v3.md](docs/contract_v3.md)）

**一句话**：把整条音频处理链按“人类操作式”拆成**独立 CLI 步骤**（单进程、磁盘交接、参数全锁定），逐段校验与落盘，
最大化稳定性与可复现性。

## 目录

- [背景与目标](#背景与目标)
- [整体流程（Stepflow）](#整体流程stepflow)
- [核心特性](#核心特性)
- [目录结构](#目录结构)
- [快速开始（Quick Start）](#快速开始quick-start)
- [环境与依赖](#环境与依赖)
- [模型与路径约定](#模型与路径约定)
- [运行入口](#运行入口)
- [编排器（ssflow）与 Manifest](#编排器ssflow与-manifest)
- [CLI 步骤参考](#cli-步骤参考)
- [质量护栏与报告](#质量护栏与报告)
- [并发与吞吐策略](#并发与吞吐策略)
- [失败恢复与可复现](#失败恢复与可复现)
- [Roadmap](#roadmap)
- [Snakemake 参考资料](#snakemake-参考资料)
- [FAQ](#faq)
- [许可与第三方声明](#许可与第三方声明)

---

## 背景与目标

**Seperate02** 是对上一代“把多模型揉进一个长进程”的彻底重构：

- 每一步骤都是**单独的命令行程序（CLI）**，读一个文件→写一个文件，**固定参数/固定模型**（契约锁定）。
- 步骤之间只通过**磁盘文件交接**，每步结束立刻做**护栏校验**（采样率/时长漂移/LUFS/峰值/能量等）。
- 任意一步失败立即停止，**之前已通过的产物保留**，定位与恢复成本极低。

适用场景：本地 Mac、Runpod、Colab、或任意无交互的批处理环境。

---

## 整体流程（Stepflow）

```text
[输入歌曲] → ① UVR 分离(人声/伴奏)
              → ② UVR 主人声提取
              → ③ UVR 去混响/降噪
              → ④ RVC 变声（固定模型+Index）
              → ⑤ 重采样/响度回整 & 结果落盘
```

**锁定采样率策略**：

- UVR 全链内部统一 **44.1 kHz / mono / float32**；
- RVC 合成 **48 kHz**；Hubert/RMVPE **16 kHz**（内部派生）；
- 最终交付：**48 kHz / 24-bit PCM**。

---

## 核心特性

- **契约锁定（Contract-Locked）**：模型、参数、窗口、overlap、响度目标全写死，避免“选项=错误面”。
- **进程隔离**：一步一进程，显存/线程/缓存随进程销毁，避免资源污染与随机报错。
- **护栏严格**：采样率、时长漂移（≤0.5%）、LUFS、峰值上限、能量下限全部硬性校验。
- **可测可复现**：每步产物 + `trace.json` + `quality_report.json`；失败可断点续跑。
- **无 GUI 依赖**：纯 CLI + 静态 HTML 报告（可选），适合自动化与规模化。

---

## 目录结构

当前仓库主要由一组 shell 脚本组成，用于串行跑完整条音频处理链：

```text
Seperate02/
├─ README.md
├─ requirements-locked.txt
├─ .env.example                # 环境变量示例
├─ scripts/
│  ├─ 00_setup_env.sh          # 安装依赖并准备目录
│  ├─ 10_separate_inst.sh      # ① UVR 分离
│  ├─ 20_extract_main.sh       # ② 主人声提取
│  ├─ 30_dereverb_denoise.sh   # ③ 去混响/降噪
│  ├─ 40_rvc_convert.sh        # ④ RVC 变声
│  ├─ 50_finalize_and_report.py# ⑤ 重采样/响度 & 报告
│  ├─ run_one.sh               # 串行跑一首歌
│  └─ run_batch.sh             # 基于队列并发批处理
└─ contracts/                  # 契约文件等（可选）
```

---

## 快速开始（Quick Start）

必须先挂载 /vol（Network Volume）
![mount /vol screenshot placeholder](docs/mount_vol_placeholder.png)

### Runpod 配置建议

* **Container Disk**：10–20 GiB
* **Volume Disk**：≥100 GiB，挂载路径固定 `/vol`
* `/workspace` 为容器根盘，重建后内容会丢失；`/vol` 为持久网络盘，模型和缓存应全部放在 `/vol`
* 容器初始化后先运行 `make preflight` 检查环境与空间

> **提示**：长命令可通过 `\` 分行，或使用 `tmux` 保持会话。

### OAuth 推荐配置

建议使用私有 OAuth 客户端或 Service Account，在本地执行 `rclone authorize "drive"` 生成配置，将结果写入 `/vol/rclone/rclone.conf` 并设置：

```bash
export RCLONE_CONFIG=/vol/rclone/rclone.conf
```

`rclone.conf` 样例：

```conf
[gdrive]
 type = drive
 scope = drive
 client_id = <your_client_id>
 client_secret = <your_client_secret>
 token = {"access_token":"...","refresh_token":"...","expiry":"..."}
```

### 常见故障速查

- FFmpeg 缺失 → `apt-get install -y ffmpeg`
- 403 / 配额 → 使用私有 OAuth 或 Service Account
- `operands could not be broadcast` → 20/30 步统一 44.1 kHz + `--mdx_hop_length 1024`
- `.src` 缺失 → 重跑 `gdrive_pull_inputs.sh` 或手工创建仅含 `local_inbox_path`


### 首次启动（8 行清单）

```bash
# 0) 体检与空间
make preflight # 不足则 make clean-cache

# 1) 安装到 /vol（双环境）
make setup-split

# 2) 模型同步到 /vol
RCLONE_CONFIG=/vol/rclone/rclone.conf bash scripts/gdrive_sync_models.sh

# 3) Index 先行（可选）
"$SS_RVC_VENV/bin/python" scripts/70_build_index_from_wav.py \
  --wav /vol/inbox/my_voice_clean.wav \
  --out /vol/models/RVC/G_8200.index
rclone copy /vol/models/RVC/G_8200.index gdrive:Seperate02/models --checksum

# 4) 拉歌并运行
bash scripts/gdrive_pull_inputs.sh
slug=$(find /vol/work -mindepth 2 -maxdepth 2 -name .lock -printf '%h\n' | sed -n '1p' | xargs -I{} basename {})
bash scripts/run_one.sh "$slug" /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index v2
```

### 自检

```bash
# UVR
/vol/venvs/uvr/bin/audio-separator --version || echo "[MISS] audio-separator"

# RVC
/vol/venvs/rvc/bin/python - <<'PY'
import numpy as np, torch
print("NumPy:", np.__version__)
print("Torch:", torch.__version__, "CUDA:", torch.cuda.is_available())
PY
(/vol/venvs/rvc/bin/rvc --help | head -n 3) || (/vol/venvs/rvc/bin/python -m rvc --help | head -n 3) || echo "[MISS] rvc"
```

### 挂载与路径

所有虚拟环境、模型、缓存、临时文件等重资产均位于挂载的 Network Volume `/vol`，运行前请确保该路径已存在。

### 低空间环境策略

```bash
make doctor
make clean-cache
```

下面示例以 Linux/Mac 为例；Windows 可使用 WSL。

1. **克隆仓库并安装依赖**

```bash
git clone https://github.com/FusinKoo/Seperate02.git
cd Seperate02
make setup-split                # 生成双虚拟环境并安装依赖
```

2. **配置环境变量**

```bash
cp .env.example .env            # 按需修改路径
source scripts/env.sh           # 加载 .env
```

3. **放置模型权重**（见下节“模型与路径约定”）

4. **运行单首歌曲**

```bash
bash scripts/run_one.sh /vol/inbox/demo.wav /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index
# 或已配置 .env 后：
bash scripts/run_one.sh demo
```

5. **批量处理（可选）**

```bash
bash scripts/run_batch.sh /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index
```

脚本输出包括：

- `01_accompaniment.wav`, `01_vocals_mix.wav`
- `02_main_vocal.wav`, `03_main_vocal_dry.wav`, `04_vocal_converted.wav`
- `quality_report.json`、`trace.json`

---

## 环境与依赖

该项目使用 UVR 与 RVC 双虚拟环境，分别锁定 NumPy 2 与 NumPy 1.23，以避免依赖冲突。

- **操作系统**：Linux / macOS（Apple Silicon 可用 CPU 跑通，建议 GPU 环境）
- **Python**：3.10+（建议 3.10/3.11）
- **GPU**（建议）：CUDA 12.x + ONNX Runtime GPU 版（`onnxruntime-gpu`）
- **离线安装**（可选）：使用 `wheelhouse/` 缓存 `pip wheel -r requirements-locked.txt` 生成的依赖包

**注意**：本仓库不包含任何第三方模型权重；请在本地/私有存储中按约定路径放置。

---

## 模型与路径约定

通过 `SS_MODELS_DIR` 作为根目录，按以下结构放置（示例）：

```text
$SS_MODELS_DIR/
├─ UVR/
│  ├─ UVR-MDX-NET-Inst_HQ_3.onnx        # 步骤① 分离
│  ├─ Kim_Vocal_2.onnx                   # 步骤② 主人声提取
│  └─ Reverb_HQ_By_FoxJoy.onnx           # 步骤③ 去混响/降噪
└─ RVC/
   ├─ G_8200.pth                         # 步骤④ 变声主干
   ├─ hubert_base.pt                     # 内容编码器（16k）
   ├─ rmvpe.onnx                         # F0 提取（16k）
   └─ G_8200.index                       # 检索库 Index（强制启用）
```

如果你使用不同文件名/模型，请在对应 CLI 内**硬编码**并随 `trace.json` 记录。
UVR 使用 `audio-separator 0.35.2`，参数映射：`--chunk`=分块大小、`--overlap`=重叠、`--fade_overlap`=窗函数。各步骤常量如下：

- 分离：`--chunk 10 --overlap 5 --fade_overlap hann`
- 主人声：`--chunk 8 --overlap 4 --fade_overlap hann`
- 去混响：`--chunk 8 --overlap 4 --fade_overlap hann`

---

## 运行入口

### Index 先行剧本

1. 上传清洁的人声 WAV 至 `inbox`
2. 生成 Index：`${SS_RVC_VENV:-/vol/venvs/rvc}/bin/python scripts/70_build_index_from_wav.py --wav /vol/inbox/my_voice_clean.wav --out /vol/models/RVC/G_8200.index`
3. 使用 `rclone copy` 将生成的 `.index` 回传


### 极简脚本（推荐）

```bash
# 单首
# 显式路径：
./scripts/run_one.sh <input_file> <rvc_pth> <index> [v1|v2]
# 使用环境变量：
./scripts/run_one.sh <slug>

# 批量（不同歌曲并发 N 首；同一首内部严格串行）：
bash scripts/run_batch.sh <rvc_pth> <index> [v1|v2]
```

### `.env.example` 示例

```dotenv
SS_MODELS_DIR=/vol/models
SS_INBOX=/vol/inbox
SS_WORK=/vol/work
SS_OUT=/vol/out
# ONNX Runtime providers 顺序（显卡优先，CPU 兜底）
SS_ORT_PROVIDERS=CUDA,CPU
# 并行度（批量层面）；同一首歌始终串行
SS_PARALLEL_JOBS=4
```

---

## 编排器（ssflow）与 Manifest

`examples/demo.yaml`：

```yaml
slug: demo
input: ${SS_INBOX}/demo.wav
steps:
  - uvr_separate
  - uvr_lead_extract
  - uvr_dereverb
  - rvc_convert_locked
  - finalize_loudness
```

运行：

```bash
python -m stepflow.cli.ssflow --manifest examples/demo.yaml
```

**说明**：Manifest 只描述顺序；参数与模型路径已在各 CLI 内“契约锁定”。

---

## CLI 步骤参考

约定：所有 CLI 只暴露 `--in/--out`（以及必须的路径参数），其他参数**全部锁定**在代码中。

### ① `uvr_separate`

- **输入**：`<slug>.wav`
- **输出**：`01_accompaniment.wav`、`01_vocals_mix.wav`
- **锁定**：SR=44.1k、mono、float32；`--mdx_segment_size 10 --mdx_overlap 5 --normalization 1.0`；ORT providers 固定为 `CUDA,CPU`。
- **失败即退出码非 0**；日志写入 `trace.json`。

### ② `uvr_lead_extract`

- **输入**：`01_vocals_mix.wav`
- **输出**：`02_main_vocal.wav`
- **锁定**：`--mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0`；后处理阈值/平滑/最小时长按契约固定。

### ③ `uvr_dereverb`

- **输入**：`02_main_vocal.wav`
- **输出**：`03_main_vocal_dry.wav`
- **锁定**：`--mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0`；100% 干声输出。

### ④ `rvc_convert_locked`

- **输入**：`03_main_vocal_dry.wav`
- **输出**：`04_vocal_converted.wav`（48 kHz / 24-bit PCM）
- **锁定**：

  - RVC 主干 48k；Hubert/RMVPE 16k（内部派生）。
  - `f0_method=rmvpe`、`index_rate=0.75`、`protect=0.33`、`rms_mix_rate=0.0`、`pitch_shift=0`。
  - `chunk_size=64`、`crossfade=0.05s`、`device=cuda`；强制启用指定 `.index`。

### ⑤ `finalize_loudness`

- **输入**：

  - 伴奏：`01_accompaniment.wav`（内部重采样→48k/24-bit）
  - 主唱：`04_vocal_converted.wav`
- **输出**：

  - `01_accompaniment.wav`（48k/24-bit）
  - `quality_report.json`
- **锁定**：目标 LUFS：伴奏 **-20.0 LUFS**、人声 **-18.5 LUFS**；**峰值 ≤ -3 dBFS**；不合格则按“**双轨同比例缩放**”回整。

### 护栏：`guard_check`

- 校验：SR、声道、样本长度（相对漂移 ≤ 0.5%）、峰值上限、能量下限。
- 不通过立即 `exit 1` 并写失败原因。

### 追踪：`trace_writer`

- 每步记录：模型/版本/路径、ORT providers、耗时、输入输出哈希、采样率/长度摘要、退出码。

---

## 质量护栏与报告

- **`quality_report.json`**：最终响度、峰值、DR/crest、时长对齐、是否触发回整；
- **`trace.json`**：全链路元数据（步骤顺序/模型/参数/耗时/错误栈）；
- **（可选）`report.html`**：只读静态报告，渲染上述 JSON；**与运行解耦**，不影响稳定性。

---

## 并发与吞吐策略

- **同一首歌**：严格串行（避免资源污染）。
- **多首歌**：进程级并行（如 `xargs -P 4` 或 Makefile 的 `-j`），由 OS/GPU 调度；显存更可控。
- 建议按显存容量与模型峰值占用评估 `SS_PARALLEL_JOBS`。

---

## 失败恢复与可复现

- 任一步失败仅影响该步及其下游；**中间件与上游结果保留**。
- 重新执行会**从最近的未通过产物继续**。
- `trace.json` 持久化所有关键元数据，确保复现实验与问题定位。

---

## Roadmap

- [ ] 生成 `report.html` 的静态报告器（仅渲染 JSON）
- [ ] 可选的 Snakemake/Make 编排（不改变现有入口）
- [ ] Docker 镜像（锁定 CUDA/ORT/Python 版本）
- [ ] CI：仅做 lint/构建，不跑模型（避免泄露与不稳定）
- [ ] 指标采集：批处理成功率、耗时分布、显存峰值（写入 trace）

---

## Snakemake 参考资料

- 官网：[Snakemake](https://snakemake.github.io)
- 文档首页：[Snakemake 9.x Docs](https://snakemake.readthedocs.io/en/stable/)
- 安装指南：[Installation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html)
- CLI 参考：[Command Line Interface](https://snakemake.readthedocs.io/en/stable/executing/cli.html)
- 源码仓库：[GitHub - snakemake/snakemake](https://github.com/snakemake/snakemake)
- Profiles 生态：[Snakemake Profiles](https://snakemake.readthedocs.io/en/stable/executing/profile.html)

---

## FAQ

**Q1. 为什么不做图形界面？**
为稳定与可测，先用 CLI + 静态报告；以后若需要 UI，也做**只读**且与运行解耦。

**Q2. 为什么不做“单进程端到端”？**
多模型长进程易产生显存/线程/缓存污染，排错与恢复成本高；拆步能显著降低随机报错概率。

**Q3. 我能调整参数吗？**
本仓库定位为**契约锁定版**；若需实验版，请另开分支/仓库，避免影响稳定流。

---

## 许可与第三方声明

- 建议采用 **MIT License**（或按你团队要求替换）。
- 本仓库不包含任何第三方模型权重；使用者需自行遵循相应许可条款。
- 任何品牌与模型名称仅用于说明，不代表背书。

---

**命名建议**：本项目在文档中可简称 **CLS/Stepflow**；对外可称 “Seperate02（Contract-Locked Stepflow）”。
