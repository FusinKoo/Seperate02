"""Snakemake pipeline for vocal separation and conversion."""
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

rule A:
    conda: "envs/a.yml"
    output:
        inst=f"{SS_WORK}/{SLUG}/01_accompaniment.wav",
        voc =f"{SS_WORK}/{SLUG}/01_vocals_mix.wav"
    log: f"logs/A/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"

      SRC_FILE="/vol/work/{SLUG}/.src"
      IN_PATH=""
      if [[ -f "$SRC_FILE" ]]; then
        IN_PATH="$(awk -F= '$1=="local_inbox_path"{print $2}' "$SRC_FILE" || true)"
      fi
      if [[ -z "${IN_PATH:-}" ]]; then
        IN_PATH="/vol/inbox/{SLUG}.wav"
      fi
      if [[ ! -f "$IN_PATH" ]]; then
        echo "[ERR] input not found: $IN_PATH (slug={SLUG})" >&2
        exit 2
      fi

      bash scripts/10_A_run.sh "$IN_PATH" "{SLUG}" &> {log}
      test -f "{output.inst}" -a -f "{output.voc}"
    """

rule B:
    conda: "envs/b.yml"
    input: f"{SS_WORK}/{SLUG}/01_vocals_mix.wav"
    output: f"{SS_WORK}/{SLUG}/02_main_vocal.wav"
    log: f"logs/B/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      bash scripts/20_B_run.sh "{SLUG}" &> {log}
      test -f "{output}"
    """

rule C:
    conda: "envs/c.yml"
    input: f"{SS_WORK}/{SLUG}/02_main_vocal.wav"
    output: f"{SS_WORK}/{SLUG}/03_main_vocal_clean.wav"
    log: f"logs/C/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      bash scripts/30_C_run.sh "{SLUG}" &> {log}
      test -f "{output}"
    """

rule D:
    conda: "envs/d.yml"
    input:
        main=f"{SS_WORK}/{SLUG}/03_main_vocal_clean.wav"
    output:
        f"{SS_WORK}/{SLUG}/04_vocal_converted.wav"
    params:
        pth=RVC_PTH, idx=RVC_IDX, ver=RVC_VER
    log: f"logs/D/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      bash scripts/40_D_rvc.sh "{SLUG}" "{params.pth}" "{params.idx}" "{params.ver}" &> {log}
      test -f "{output}"
    """

rule E:
    conda: "envs/e.yml"
    input:
        f"{SS_WORK}/{SLUG}/04_vocal_converted.wav"
    output:
        f"{SS_OUT}/{SLUG}/quality_report.json"
    log: f"logs/E/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      python scripts/50_E_finalize_and_report.py --slug "{SLUG}" &> {log}
      test -f "{output}"
    """
