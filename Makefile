.RECIPEPREFIX := >
.PHONY: help setup-lock setup-split setup sanity dag demo env one pull batch push backup preflight doctor clean-cache index-first wheels-prepare wheels-pull wheels-push venv-clean hooks lock-refresh uv-setup uv-install

CHECK_VOL := if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; fi

help:
> @$(CHECK_VOL)
> @echo "Quick start: bash scripts/bootstrap.sh"
> @echo "Targets:"
> @echo "  setup-lock  - install deps via lock file"
> @echo "  setup-split - install dual venvs"
> @echo "  sanity      - snakemake dry-run"
> @echo "  dag         - export workflow DAG to audit/snakedag.dot"
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
> @if ! mountpoint -q /vol; then echo "[ERR] /vol not mounted. Attach Network Volume at /vol, then rerun 'make setup-lock'." >&2; exit 2; fi; \
> H=$$(grep -c -- '--hash=sha256:' requirements-locked.txt || true); \
  if [ "$$H" -gt 0 ]; then \
    echo "[INFO] using --require-hashes"; \
    python3 -m venv ${SS_VENVS_DIR}/uvr && ${SS_VENVS_DIR}/uvr/bin/pip install -U pip && ${SS_VENVS_DIR}/uvr/bin/pip install --require-hashes -r requirements-locked.txt; \
  else \
    echo "[WARN] no hashes in requirements-locked.txt; installing without --require-hashes"; \
    python3 -m venv ${SS_VENVS_DIR}/uvr && ${SS_VENVS_DIR}/uvr/bin/pip install -U pip && ${SS_VENVS_DIR}/uvr/bin/pip install -r requirements-locked.txt; \
  fi

setup:
> if [ "$${SS_USE_UV:-0}" = "1" ]; then \
>   $(MAKE) uv-setup; \
> else \
>   bash scripts/00_setup_env_split.sh; \
> fi
sanity:
> @./scripts/snk -s Snakefile -n --cores 1 --printshellcmds

dag:
> @mkdir -p audit
> @./scripts/snk -s Snakefile -n --dag > audit/snakedag.dot
> @command -v dot >/dev/null && dot -Tpng audit/snakedag.dot -o audit/snakedag.png || true

demo:
> bash scripts/run_one.sh ${SS_INBOX}/demo.wav ${SS_MODELS_DIR}/RVC/G_8200.pth ${SS_MODELS_DIR}/RVC/G_8200.index v2

env:
> @echo SS_INBOX=${SS_INBOX}
> @echo SS_WORK=${SS_WORK}
> @echo SS_OUT=${SS_OUT}
> @echo SS_MODELS_DIR=${SS_MODELS_DIR}
> @echo SS_ASSETS_DIR=${SS_ASSETS_DIR}

one:
> @./scripts/snk -s Snakefile --cores 1 --resources gpus=1 -k --config slug=$(song)

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
> @rm -rf ${SS_VENVS_DIR}/uvr ${SS_VENVS_DIR}/rvc

preflight:
> @mount | grep -E '[[:space:]]/vol[[:space:]]' || echo "[ERR] /vol 未挂载"
> @df -h / /vol || true
> @echo "RCLONE_CONFIG=$$RCLONE_CONFIG"; test -f "$$RCLONE_CONFIG" || echo "[WARN] RCLONE_CONFIG 未设置"
> bash scripts/sanity_check.sh || true
> bash scripts/doctor_space.sh || true

setup-split:
> @if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; else bash scripts/00_setup_env_split.sh; fi

doctor:
> @if ! mountpoint -q /vol; then echo "[WARN] /vol not mounted. Attach Network Volume at /vol"; else bash scripts/doctor_space.sh; fi

clean-cache:
> bash scripts/cleanup_caches.sh

index-first:
> @echo "Use scripts/70_build_index_from_wav.py to build index:"
> @echo "  ${SS_RVC_VENV:-${SS_VENVS_DIR}/rvc}/bin/python scripts/70_build_index_from_wav.py --wav <in.wav> --out <out.index>"

# --- Snakemake integration ---
snk-dry:
> ./scripts/snk -s Snakefile -n --cores 1 --printshellcmds

snk-run:
> ./scripts/snk -s Snakefile --cores 1 --printshellcmds

snk-run-slug:
> ./scripts/snk -s Snakefile --cores 1 --config slug="$(slug)"

.PHONY: lock-refresh
lock-refresh:
> pip install -U pip-tools
> pip-compile --generate-hashes -o requirements-locked.txt requirements-uvr.txt requirements-rvc.txt

uv-setup:
> if ! command -v uv >/dev/null 2>&1; then \
>   echo "[ERR] uv not found. Set SS_USE_UV=0 or install uv first (https://github.com/astral-sh/uv)."; exit 2; \
> fi
> uv venv ${SS_VENVS_DIR}/uvr
> . ${SS_VENVS_DIR}/uvr/bin/activate && uv pip install -r requirements-locked.txt

uv-install:
> . ${SS_VENVS_DIR}/uvr/bin/activate && uv pip install -r requirements-locked.txt

hooks:
> pip install pre-commit
> pre-commit install
