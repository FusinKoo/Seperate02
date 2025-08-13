setup:
	bash scripts/00_setup_env.sh

sanity:
	bash scripts/sanity_check.sh

one:
	bash scripts/run_one.sh $(song)

batch:
	bash scripts/run_batch.sh $(model) $(index) $(ver)

backup:
	bash scripts/90_backup_gdrive.sh
