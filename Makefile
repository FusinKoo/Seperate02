.RECIPEPREFIX := >
.PHONY: help setup-lock setup-split setup sanity demo env one pull batch push backup doctor clean-cache index-first

help:
> @echo "Targets:"
> @echo "  setup-lock  - install deps via lock file"
> @echo "  setup-split - install dual venvs"
> @echo "  sanity      - run environment checks"
> @echo "  demo        - run demo song with fixed paths"
> @echo "  env         - show key environment vars"
> @echo "  one song=<slug>"
> @echo "  pull        - pull songs from gdrive"
> @echo "  batch model=<pth> index=<idx> ver=<v1|v2>"
> @echo "  push        - push processed outputs"
> @echo "  backup      - backup outputs to gdrive"
> @echo "  doctor      - space check"
> @echo "  clean-cache - remove caches"
> @echo "  index-first - build RVC index"

setup-lock:
> bash scripts/00_setup_env_split.sh

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

setup-split:
> - bash scripts/00_setup_env_split.sh || true

doctor:
> - bash scripts/doctor_space.sh || true

clean-cache:
> bash scripts/cleanup_caches.sh

index-first:
> @echo "Use scripts/70_build_index_from_wav.py to build index:"
> @echo "  ${SS_RVC_VENV:-/vol/venvs/rvc}/bin/python scripts/70_build_index_from_wav.py --wav <in.wav> --out <out.index>"
