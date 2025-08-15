# -*- coding: utf-8 -*-
import os

# 配置优先顺序：命令行 --config > config/config.yaml > 环境变量/默认值
configfile: "config/config.yaml" if os.path.exists("config/config.yaml") else None

SS_WORK  = config.get("SS_WORK",  os.getenv("SS_WORK",  "/vol/work"))
SS_OUT   = config.get("SS_OUT",   os.getenv("SS_OUT",   "/vol/out"))
RVC_PTH  = config.get("rvc_pth",  os.getenv("SS_RVC_PTH",  "/vol/models/RVC/G_8200.pth"))
RVC_IDX  = config.get("rvc_index",os.getenv("SS_RVC_INDEX","/vol/models/RVC/G_8200.index"))
RVC_VER  = config.get("rvc_ver",  os.getenv("SS_RVC_VER",  "v2"))
SLUG     = config.get("slug", None)

if SLUG is None:
    raise ValueError("Missing required config: slug (可用 --config slug=... 传入；或在 config/config.yaml 中配置)")

rule all:
    input:
        f"{SS_OUT}/{SLUG}/quality_report.json"

rule end_to_end:
    output:
        f"{SS_OUT}/{SLUG}/quality_report.json"
    shell:
        r"""
        # 说明：依赖现有 run_one.sh 串行执行 10/20/30/40/50 并生成 quality_report.json
        # run_one.sh 支持传入 slug（需要 .src 已存在），或直接传入音频路径。
        # 这里我们约定 slug 模式（更稳健）；请先用 gdrive_pull_inputs.sh 将歌曲拉到 /vol 并生成 .src。
        bash scripts/run_one.sh "{SLUG}" "{RVC_PTH}" "{RVC_IDX}" "{RVC_VER}"

        test -f "{SS_OUT}/{SLUG}/quality_report.json" || {{
          echo "[ERR] missing quality_report.json for slug={SLUG}" >&2; exit 3;
        }}
        """

