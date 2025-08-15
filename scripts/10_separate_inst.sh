#!/usr/bin/env bash
set -euo pipefail
usage(){
  cat <<USG
Usage: $(basename "$0") [--use-soundfile] <input_file> <slug>
Desc : Step-10 UVR 分离伴奏与主唱，产出 01_accompaniment.wav / 01_vocals_mix.wav
Opts : --use-soundfile  使用 soundfile 写盘（也可用 SS_UVR_USE_SOUNDFILE=1）
USG
}
USE_SF=${SS_UVR_USE_SOUNDFILE:-0}
case "${1:-}" in -h|--help) usage; exit 0;; --use-soundfile) USE_SF=1; shift;; esac
IN=${1:-}; SLUG=${2:-}; [[ -f "${IN:-}" && -n "${SLUG:-}" ]] || { usage; exit 2; }
set +u; [ -f .env ] && . .env; set -u
SS_WORK="${SS_WORK:-/vol/work}"; SS_MODELS_DIR="${SS_MODELS_DIR:-/vol/models}"; SS_UVR_VENV="${SS_UVR_VENV:-/vol/venvs/uvr}"
UVR_BIN="$SS_UVR_VENV/bin/audio-separator"; MODEL_DIR="$SS_MODELS_DIR/UVR"; MODEL="UVR-MDX-NET-Inst_HQ_3.onnx"
WORK_DIR="$SS_WORK/$SLUG"; mkdir -p "$WORK_DIR"
cmd=( "$UVR_BIN" -m "$MODEL" --model_file_dir "$MODEL_DIR" --output_dir "$WORK_DIR" --output_format WAV
      --mdx_segment_size 10 --mdx_overlap 5 --normalization 1.0 --amplification 0 )
[[ "$USE_SF" == "1" ]] && cmd+=( --use_soundfile )
"${cmd[@]}" "$IN"
shopt -s nullglob
inst=( "$WORK_DIR"/*"(Instrumental)"*UVR-MDX-NET-Inst_HQ_3.wav ); voc=( "$WORK_DIR"/*"(Vocals)"*UVR-MDX-NET-Inst_HQ_3.wav )
[[ ${#inst[@]} -ge 1 ]] || { echo "[ERR] Instrumental stem not found"; exit 3; }
[[ ${#voc[@]}  -ge 1 ]] || { echo "[ERR] Vocals stem not found"; exit 3; }
mv -f "${inst[0]}" "$WORK_DIR/01_accompaniment.wav"; mv -f "${voc[0]}"  "$WORK_DIR/01_vocals_mix.wav"
echo "[OK] 10 -> 01_accompaniment.wav, 01_vocals_mix.wav"
