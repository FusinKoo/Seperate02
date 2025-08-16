# Snakemake

Snakemake is used purely as an orchestration layer around the existing
`scripts/run_one.sh` pipeline. Algorithm logic remains unchanged.

## Usage

Dry‑run the workflow:

```bash
make snk-dry
```

Run a specific slug:

```bash
make snk-run-slug slug=<slug>
```

Outputs are written under `${SS_OUT}/<slug>` and the step log is stored at
`logs/<slug>/end_to_end.log`.
