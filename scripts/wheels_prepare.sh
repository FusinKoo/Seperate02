#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- helpers ----------
die(){ echo "[ERR] $*" >&2; exit 2; }
env_or(){ local v="${!1:-}"; [[ -n "$v" ]] && echo "$v" || echo "$2"; }

# ---------- profile ----------
PYTAG=$(python3 - <<'PY'
import sys; print(f"cp{sys.version_info.major}{sys.version_info.minor}")
PY
)
UNAME="$(uname -s | tr A-Z a-z)_$(uname -m)"
PROFILE="${SS_WHEEL_PROFILE:-${PYTAG}-${SS_CUDA_TAG:-cu124}-${UNAME}}"

BASE="${SS_WHEELHOUSE:-/vol/wheels}/${PROFILE}"
WH_UVR="${BASE}/uvr"
WH_RVC="${BASE}/rvc"
WH_LOCK="${BASE}/lock"

mkdir -p "$WH_UVR" "$WH_RVC" "$WH_LOCK"

# ---------- venv sanity (we just need pip, so allow system pip fallback) ----------
UVR_PIP="${SS_UVR_VENV:-/vol/venvs/uvr}/bin/pip"
RVC_PIP="${SS_RVC_VENV:-/vol/venvs/rvc}/bin/pip"
command -v "$UVR_PIP" >/dev/null 2>&1 || UVR_PIP="pip"
command -v "$RVC_PIP" >/dev/null 2>&1 || RVC_PIP="pip"

echo "[INF] PROFILE=$PROFILE"
echo "[INF] wheelhouse=$BASE"

# ---------- download ----------
set -x
"$UVR_PIP" download -r requirements-uvr.txt -d "$WH_UVR"
"$RVC_PIP" download -r requirements-rvc.txt -d "$WH_RVC"
if [[ -f requirements-locked.txt ]]; then
  "$UVR_PIP" download -r requirements-locked.txt -d "$WH_LOCK" || true
fi
set +x

echo "[OK] wheels prepared under $BASE"
