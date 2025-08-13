.RECIPEPREFIX := >
.PHONY: help setup-lock sanity demo env one pull batch push backup

help:
> @echo "Targets:"
> @echo "  setup-lock  - install deps via lock file"
> @echo "  sanity      - run environment checks"
> @echo "  demo        - run demo song with fixed paths"
> @echo "  env         - show key environment vars"
> @echo "  one song=<slug>"
> @echo "  pull        - pull songs from gdrive"
> @echo "  batch model=<pth> index=<idx> ver=<v1|v2>"
> @echo "  push        - push processed outputs"
> @echo "  backup      - backup outputs to gdrive"

setup-lock:
> bash scripts/00_setup_env.sh

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
