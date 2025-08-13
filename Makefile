.RECIPEPREFIX := >
.PHONY: help setup-lock sanity demo env one batch backup

help:
> @echo "Targets:"
> @echo "  setup-lock  - install deps via lock file"
> @echo "  sanity      - run environment checks"
> @echo "  demo        - run demo song with fixed paths"
> @echo "  env         - show key environment vars"
> @echo "  one song=<slug>"
> @echo "  batch model=<pth> index=<idx> ver=<v1|v2>"
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

batch:
> bash scripts/run_batch.sh $(model) $(index) $(ver)

backup:
> bash scripts/90_backup_gdrive.sh
