#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"
PROFILE="${SS_WHEEL_PROFILE:-$(python3 - <<'PY'
import sys,platform
print(f"cp{sys.version_info.major}{sys.version_info.minor}-" +
      f"{__import__('os').environ.get('SS_CUDA_TAG','cu124')}-" +
      f"{platform.system().lower()}_{platform.machine()}")
PY
)}"
BASE="${SS_WHEELHOUSE:-${SS_WHEELS_DIR}}/${PROFILE}"
REMOTE="${SS_WHEELS_REMOTE:?missing SS_WHEELS_REMOTE}/${PROFILE}"
mkdir -p "$BASE"

set +e
rclone lsd "$REMOTE" >/dev/null 2>/dev/null
has_remote=$?
set -e
if [[ $has_remote -ne 0 ]]; then
  echo "[WARN] remote wheelhouse not found: $REMOTE"
else
  rclone copy "$REMOTE" "$BASE" --checksum --fast-list \
    --transfers "${SS_RCLONE_TRANSFERS:-4}" --checkers "${SS_RCLONE_CHECKERS:-8}" \
    --drive-chunk-size "${SS_RCLONE_CHUNK:-64M}"
fi
