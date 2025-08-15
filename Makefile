.RECIPEPREFIX := >
.PHONY: help setup-lock setup-split setup sanity demo env one pull batch push backup preflight doctor clean-cache index-first wheels-prepare wheels-pull wheels-push venv-clean

CHECK_VOL := if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; fi

help:
> @$(CHECK_VOL)
> @echo "Targets:"
> @echo "  setup-lock  - install deps via lock file"
> @echo "  setup-split - install dual venvs"
> @echo "  sanity      - run environment checks"
> @echo "  demo        - run demo song with fixed paths (make demo)"
> @echo "  env         - show key environment vars (make env)"
> @echo "  one song=<slug>"
> @echo "  pull        - pull songs from gdrive"
> @echo "  batch model=<pth> index=<idx> ver=<v1|v2>"
> @echo "  push        - push processed outputs"
> @echo "  backup      - backup outputs to gdrive"
> @echo "  wheels-prepare - predownload wheels"
> @echo "  wheels-pull    - pull wheels from gdrive"
> @echo "  wheels-push    - push wheels to gdrive"
> @echo "  venv-clean     - remove venvs"
> @echo "  doctor      - space check"
> @echo "  preflight   - run sanity and space checks"
> @echo "  clean-cache - remove caches"
> @echo "  index-first - build RVC index (make index-first wav=<in.wav> out=<out.index>)"

setup-lock:
> pip install -r requirements-locked.txt --require-hashes

setup:
> bash scripts/00_setup_env_split.sh

sanity:
> bash scripts/sanity_check.sh

demo:
> bash scripts/run_one.sh /vol/inbox/demo.wav /vol/models/RVC/G_8200.pth /vol/models/RVC/G_8200.index v2

env:
> @echo SS_INBOX=${SS_INBOX:-/vol/inbox}
> @echo SS_WORK=${SS_WORK:-/vol/work}
> @echo SS_OUT=${SS_OUT:-/vol/out}
> @echo SS_MODELS_DIR=${SS_MODELS_DIR:-/vol/models}
> @echo SS_ASSETS_DIR=${SS_ASSETS_DIR:-/vol/assets}

one:
> bash scripts/run_one.sh $(song)

pull:
> bash scripts/gdrive_pull_inputs.sh

batch:
> bash scripts/run_batch.sh $(model) $(index) $(ver)

push:
> bash scripts/gdrive_push_outputs.sh

backup:
> bash scripts/90_backup_gdrive.sh

wheels-prepare:
> @bash scripts/wheels_prepare.sh

wheels-pull:
> @bash scripts/wheels_pull.sh

wheels-push:
> @bash scripts/wheels_push.sh

venv-clean:
> @rm -rf /vol/venvs/uvr /vol/venvs/rvc

preflight:
> @mount | grep -E '[[:space:]]/vol[[:space:]]' || echo "[ERR] /vol 未挂载"
> @df -h / /vol || true
> @echo "RCLONE_CONFIG=$$RCLONE_CONFIG"; test -f "$$RCLONE_CONFIG" || echo "[WARN] RCLONE_CONFIG 未设置"
> bash scripts/sanity_check.sh || true
> bash scripts/doctor_space.sh

setup-split:
> @if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; else bash scripts/00_setup_env_split.sh; fi

doctor:
> @if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; else bash scripts/doctor_space.sh; fi

clean-cache:
> bash scripts/cleanup_caches.sh

index-first:
> @echo "Use scripts/70_build_index_from_wav.py to build index:"
> @echo "  ${SS_RVC_VENV:-/vol/venvs/rvc}/bin/python scripts/70_build_index_from_wav.py --wav <in.wav> --out <out.index>"
