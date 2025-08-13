#!/usr/bin/env bash
set -euo pipefail

usage(){ cat <<USAGE
Usage: scripts/60_optional_mixdown.sh <slug>
USAGE
}
[[ "${1:-}" =~ ^(-h|--help)$ ]] && usage && exit 0

SLUG="$1"
SS_OUT=${SS_OUT:-/vol/out}
RVC_TAG=${SS_RVC_MODEL_TAG:-G_8200}
OUTDIR="$SS_OUT/${SLUG}"
BGM="${OUTDIR}/${SLUG}.instrumental.UVR-MDX-NET-Inst_HQ_3.wav"
LEAD="${OUTDIR}/${SLUG}.lead_converted.${RVC_TAG}.wav"
FINAL="${OUTDIR}/${SLUG}.mix_48k.wav"

[ -f "$BGM" ] || { echo "[ERR] $BGM"; exit 1; }
[ -f "$LEAD" ] || { echo "[ERR] $LEAD"; exit 1; }

ffmpeg -y -i "$BGM" -i "$LEAD" \
  -filter_complex "[0:a]aresample=48000,pan=stereo|c0=FL|c1=FR[a0]; \
                   [1:a]aresample=48000,pan=stereo|c0=FL|c1=FR,alimiter=limit=0.891[a1]; \
                   [a0][a1]amix=inputs=2:normalize=0:weights=1 1" \
  -ar 48000 -ac 2 -c:a pcm_s24le "$FINAL"

echo "[OK] Mixdown → $FINAL"
