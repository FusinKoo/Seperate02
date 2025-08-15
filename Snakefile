"""Snakemake wrapper for end-to-end processing."""
import os

configfile: "config/config.yaml" if os.path.exists("config/config.yaml") else None

SS_WORK  = config.get("SS_WORK",  os.getenv("SS_WORK",  "/vol/work"))
SS_OUT   = config.get("SS_OUT",   os.getenv("SS_OUT",   "/vol/out"))
RVC_PTH  = config.get("rvc_pth",  os.getenv("SS_RVC_PTH",  "/vol/models/RVC/G_8200.pth"))
RVC_IDX  = config.get("rvc_index",os.getenv("SS_RVC_INDEX","/vol/models/RVC/G_8200.index"))
RVC_VER  = config.get("rvc_ver",  os.getenv("SS_RVC_VER",  "v2"))
SLUG     = config.get("slug", None)

if SLUG is None:
    raise ValueError("Missing required config: slug")

rule all:
    input:
        f"{SS_OUT}/{SLUG}/quality_report.json"

rule step10:
    output:
        inst=f"{SS_WORK}/{SLUG}/01_accompaniment.wav",
        voc =f"{SS_WORK}/{SLUG}/01_vocals_mix.wav"
    log: f"logs/{SLUG}/10.log"
    resources: mem_mb=4096, gpu=1
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      bash scripts/10_separate_inst.sh "/vol/inbox/{SLUG}.wav" "{SLUG}" &> {log}
      test -f "{output.inst}" -a -f "{output.voc}"
    """

rule step20:
    input: f"{SS_WORK}/{SLUG}/01_vocals_mix.wav"
    output: f"{SS_WORK}/{SLUG}/02_main_vocal.wav"
    log: f"logs/{SLUG}/20.log"
    resources: mem_mb=4096, gpu=1
    shell: r"""
      set -Eeuo pipefail
      bash scripts/20_extract_main.sh "{SLUG}" &> {log}
      test -f "{output}"
    """

rule step30:
    input: f"{SS_WORK}/{SLUG}/02_main_vocal.wav"
    output: f"{SS_WORK}/{SLUG}/03_main_vocal_clean.wav"
    log: f"logs/{SLUG}/30.log"
    resources: mem_mb=4096, gpu=0
    shell: r"""
      set -Eeuo pipefail
      bash scripts/30_dereverb_denoise.sh "{SLUG}" &> {log}
      test -f "{output}"
    """

rule step40:
    input:
        main=f"{SS_WORK}/{SLUG}/03_main_vocal_clean.wav"
    output:
        f"{SS_WORK}/{SLUG}/04_converted.wav"
    params:
        pth=RVC_PTH, idx=RVC_IDX, ver=RVC_VER
    log: f"logs/{SLUG}/40.log"
    resources: mem_mb=4096, gpu=1
    shell: r"""
      set -Eeuo pipefail
      bash scripts/40_rvc_convert.sh "{SLUG}" "{params.pth}" "{params.idx}" "{params.ver}" &> {log}
      test -f "{output}"
    """

rule step50:
    input:
        f"{SS_WORK}/{SLUG}/04_converted.wav"
    output:
        f"{SS_OUT}/{SLUG}/quality_report.json"
    log: f"logs/{SLUG}/50.log"
    resources: mem_mb=2048, gpu=0
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      {os.getenv("SS_UVR_VENV","/vol/venvs/uvr")}/bin/python scripts/50_finalize_and_report.py --slug "{SLUG}" &> {log}
      test -f "{output}"
    """
