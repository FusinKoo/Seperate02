#!/usr/bin/env bash
# common environment loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi
SS_INBOX=${SS_INBOX:-/vol/inbox}
SS_WORK=${SS_WORK:-/vol/work}
SS_OUT=${SS_OUT:-/vol/out}
SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}
SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}
SS_GDRIVE_REMOTE=${SS_GDRIVE_REMOTE:-gdrive}
SS_GDRIVE_ROOT=${SS_GDRIVE_ROOT:-Seperate02}
SS_PARALLEL_JOBS=${SS_PARALLEL_JOBS:-4}
