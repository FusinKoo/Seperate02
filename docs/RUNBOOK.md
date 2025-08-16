# RUNBOOK

Ten-minute guide for teammates or contributors to run Seperate02 pipeline.

## Hardware / Drivers
- GPU optional; CPU works but will be slower.

## Base directory
Root files live under `/workspace` by default. Override with `SS_BASE` if needed; legacy `/vol` paths are auto-symlinked.

## One-shot bootstrap
```bash
bash scripts/bootstrap.sh
```

## GDrive
```bash
export RCLONE_CONFIG=$SS_BASE/rclone/rclone.conf
make pull
```

## Single track processing
```bash
make snk-run-slug slug=<slug>
# outputs written under ${SS_OUT}/<slug>
```

## Batch processing
```bash
make batch # concurrency controlled by SS_PARALLEL_JOBS
```

## Push results back
```bash
make push
# failed songs check inbox/failed/*.reason.txt
```

## Self-check
```bash
make sanity
# shows ORT providers & dependency list
```

## Common issues
- rclone remote does not exist
- ORT runs on CPU only
- Models not yet synced
