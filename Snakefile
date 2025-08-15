import os, glob
from pathlib import Path

configfile: "config/config.yaml"

P = config["paths"]
VOL, INBOX, WORK, OUT = P["vol"], P["inbox"], P["work"], P["out"]
MODELS, ASSETS = P["models"], P["assets"]


def slugs():
    if config.get("slugs"):
        return config["slugs"]
    return [Path(p).parent.name for p in glob.glob(f"{WORK}/*/.lock")]


S = slugs()

shell.executable("/bin/bash")
os.environ["PYTHONUNBUFFERED"] = "1"


rule all:
    input: expand(f"{OUT}" + "/{slug}/quality_report.json", slug=S)


rule preflight:
    output: temp(f"{VOL}/.preflight.ok")
    shell:
        r"""
set -Eeuo pipefail
mount | grep -E '[[:space:]]/vol[[:space:]]' >/dev/null || {{ echo "[ERR] /vol 未挂载"; exit 2; }}
mkdir -p "{P['logs']}"
date -u +"%FT%TZ ok" > {output}
"""


rule sync_models:
    input: rules.preflight.output
    output: temp(f"{VOL}/.models.synced")
    run:
        if not config["gdrive"].get("enabled", False):
            shell(r'echo "[SKIP] gdrive disabled" > {output}')
        else:
            shell(r'bash scripts/gdrive_sync_models.sh && date -u +"%FT%TZ" > {output}')


rule step10_separate_inst:
    input: f"{WORK}" + "/{slug}/.lock"
    output: vocals=f"{WORK}" + "/{slug}/01_vocals_mix.wav", inst=f"{WORK}" + "/{slug}/01_accompaniment.wav"
    log: f"{P['logs']}" + "/{slug}.10.log"
    resources: gpu=config["resources"]["gpu_per_job"]
    shell:
        r"""
set -Eeuo pipefail
src=$(awk -F= '/^local_inbox_path=/{print $2}' "{WORK}/{wildcards.slug}/.src" 2>/dev/null || true)
[[ -n "$src" && -f "$src" ]] || src="{INBOX}/{wildcards.slug}.wav"
/vol/venvs/uvr/bin/audio-separator -m UVR-MDX-NET-Inst_HQ_3.onnx \
  --model_file_dir "{MODELS}/UVR" --output_dir "{WORK}/{wildcards.slug}" \
  --output_format WAV ${SS_UVR_USE_SOUNDFILE:+--use_soundfile} \
  --mdx_segment_size 10 --mdx_overlap 5 --normalization 1.0 --amplification 0 "$src" &> {log}
voc=$(ls -t "{WORK}/{wildcards.slug}"/*"(Vocals)"*"_UVR-MDX-NET-Inst_HQ_3.wav" | head -n1)
ins=$(ls -t "{WORK}/{wildcards.slug}"/*"(Instrumental)"*"_UVR-MDX-NET-Inst_HQ_3.wav" | head -n1)
cp -f "$voc" {output.vocals}; cp -f "$ins" {output.inst}
chk(){ ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=nk=1:nw=1 "$1" || echo 0; }
for f in {output.vocals} {output.inst}; do d=$(chk "$f"); awk "BEGIN{exit !($d>0)}" || ffmpeg -y -v error -i "$f" -ac 2 -ar 48000 -c:a pcm_s16le "$f"; done
"""


rule step20_extract_main:
    input: f"{WORK}" + "/{slug}/01_vocals_mix.wav"
    output: f"{WORK}" + "/{slug}/02_main_vocals.wav"
    log: f"{P['logs']}" + "/{slug}.20.log"
    shell:
        r"""
set -Eeuo pipefail
ffmpeg -y -v error -i "{input}" -ac 2 -ar 48000 -c:a pcm_s16le "{WORK}/{wildcards.slug}/01_vocals_mix.wav"
bash scripts/20_extract_main.sh "{wildcards.slug}" &> {log}
test -s {output} || {{ echo "[ERR] step20 produced empty output"; exit 2; }}
"""


rule step30_dereverb_denoise:
    input: f"{WORK}" + "/{slug}/02_main_vocals.wav"
    output: f"{WORK}" + "/{slug}/03_main_clean.wav"
    log: f"{P['logs']}" + "/{slug}.30.log"
    shell:
        r"""
set -Eeuo pipefail
bash scripts/30_dereverb_denoise.sh "{wildcards.slug}" &> {log}
test -s {output} || {{ echo "[ERR] step30 produced empty output"; exit 2; }}
"""


rule step40_rvc_convert:
    input: f"{WORK}" + "/{slug}/03_main_clean.wav"
    output: f"{WORK}" + "/{slug}/04_rvc.wav"
    log: f"{P['logs']}" + "/{slug}.40.log"
    params: pth=config["rvc"]["pth"], idx=config["rvc"]["index"], algo=config["rvc"]["algo"]
    shell:
        r"""
set -Eeuo pipefail
bash scripts/40_rvc_convert.sh "{wildcards.slug}" "{params.pth}" "{params.idx}" "{params.algo}" &> {log}
test -s {output} || {{ echo "[ERR] step40 produced empty output"; exit 2; }}
"""


rule step50_finalize_and_report:
    input: f40=f"{WORK}" + "/{slug}/04_rvc.wav", f10i=f"{WORK}" + "/{slug}/01_accompaniment.wav"
    output: f"{OUT}" + "/{slug}/quality_report.json"
    log: f"{P['logs']}" + "/{slug}.50.log"
    shell:
        r"""
set -Eeuo pipefail
/vol/venvs/uvr/bin/python scripts/50_finalize_and_report.py --slug "{wildcards.slug}" &> {log}
test -s {output}
"""

