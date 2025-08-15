"""Snakemake wrapper for end-to-end processing.

Configuration priority: command line ``--config`` > ``config/config.yaml``
> environment variables/defaults.
"""

import os

configfile: "config/config.yaml" if os.path.exists("config/config.yaml") else None

SS_WORK  = config.get("SS_WORK",  os.getenv("SS_WORK",  "/vol/work"))
SS_OUT   = config.get("SS_OUT",   os.getenv("SS_OUT",   "/vol/out"))
RVC_PTH  = config.get("rvc_pth",  os.getenv("SS_RVC_PTH",  "/vol/models/RVC/G_8200.pth"))
RVC_IDX  = config.get("rvc_index",os.getenv("SS_RVC_INDEX","/vol/models/RVC/G_8200.index"))
RVC_VER  = config.get("rvc_ver",  os.getenv("SS_RVC_VER",  "v2"))
SLUG     = config.get("slug", None) or os.environ.get("SLUG")

if SLUG is None:
    raise ValueError("Missing required slug. Pass `--config slug=<slug>` or set env `SLUG=<slug>`.")


rule all:
    input: f"{SS_OUT}/{SLUG}/quality_report.json"


rule end_to_end:
    output: f"{SS_OUT}/{SLUG}/quality_report.json"
    log:    f"logs/{SLUG}/end_to_end.log"
    shell: r"""
      set -Eeuo pipefail
      mkdir -p "$(dirname {log})"
      bash scripts/run_one.sh "{SLUG}" "{RVC_PTH}" "{RVC_IDX}" "{RVC_VER}" &> {log}
      test -f "{SS_OUT}/{SLUG}/quality_report.json" || {{ echo "[ERR] missing quality_report.json (slug={SLUG})" >&2; exit 3; }}
    """

