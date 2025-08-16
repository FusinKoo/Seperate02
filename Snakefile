"""Snakemake pipeline for vocal separation and conversion."""
import os

configfile: "config/config.yaml" if os.path.exists("config/config.yaml") else None

SS_INBOX     = config.get("SS_INBOX",     os.getenv("SS_INBOX",     "/workspace/inbox"))
SS_WORK      = config.get("SS_WORK",      os.getenv("SS_WORK",      "/workspace/work"))
SS_OUT       = config.get("SS_OUT",       os.getenv("SS_OUT",       "/workspace/out"))
SS_LOGS_DIR  = config.get("SS_LOGS_DIR",  os.getenv("SS_LOGS_DIR",  "/workspace/logs"))

# 让 slug 在 dry-run/CI 场景里有默认值，避免导入期报错
SLUG = config.get("slug", os.getenv("SS_CI_SLUG", "__ci_dryrun__"))

# 其它可选参数给下默认值（dry-run 不会真正使用）
RVC_VER   = config.get("rvc_ver",   os.getenv("RVC_VER",   "v2"))
RVC_PTH   = config.get("rvc_pth",   os.getenv("RVC_PTH",   "IGNORE"))
RVC_INDEX = config.get("rvc_index", os.getenv("RVC_INDEX", "IGNORE"))

rule all:
    input:
        f"{SS_OUT}/{SLUG}/quality_report.json"

rule A:
    conda: "envs/a.yml"
    output:
        inst=f"{SS_WORK}/{SLUG}/01_accompaniment.wav",
        voc =f"{SS_WORK}/{SLUG}/01_vocals_mix.wav"
    log: f"{SS_LOGS_DIR}/A/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"

      SRC_FILE="{SS_WORK}/{SLUG}/.src"
      IN_PATH=""
      if [[ -f "$SRC_FILE" ]]; then
        IN_PATH="$(awk -F= '$1=="local_inbox_path"{print $2}' "$SRC_FILE" || true)"
      fi
      if [[ -z "${IN_PATH:-}" ]]; then
        IN_PATH="{SS_INBOX}/{SLUG}.wav"
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
    log: f"{SS_LOGS_DIR}/B/{SLUG}.log"
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
    log: f"{SS_LOGS_DIR}/C/{SLUG}.log"
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
        pth=RVC_PTH, idx=RVC_INDEX, ver=RVC_VER
    log: f"{SS_LOGS_DIR}/D/{SLUG}.log"
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
    log: f"{SS_LOGS_DIR}/E/{SLUG}.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      python scripts/50_E_finalize_and_report.py --slug "{SLUG}" &> {log}
      test -f "{output}"
    """
