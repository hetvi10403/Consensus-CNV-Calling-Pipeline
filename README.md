# CNV Calling Pipeline (Nextflow)

A modular Nextflow (DSL2) pipeline that calls copy number variants (CNVs) from
whole-genome sequencing BAMs using three independent tools, merges the calls
into a single unified call set, and annotates them with [AnnotSV](https://lbgi.fr/AnnotSV/).

[![CI](https://github.com/hetvi10403/Consensus-CNV-Calling-Pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/hetvi10403/Consensus-CNV-Calling-Pipeline/actions/workflows/ci.yml)

## Validation status

Validated end-to-end on sample ND01039 (ENA project PRJEB87628; expected
finding: PARK2 deletion, chr6, ~156kb). The consensus pipeline produced
a deletion call at **chr6:162,089,831-162,250,000**, confirmed by direct
coordinate overlap with the known PARK2 locus.

Gene-level annotation via AnnotSV is fully integrated (`modules/annotsv.nf`)
and works end-to-end once pointed at a valid annotation data directory.
See `params.yaml` and the comments in `modules/annotsv.nf` for setup notes.

## Pipeline overview

```
                     ┌────────────┐
   sample.bam ──────▶│ INDEX_BAM  │
                     └─────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   ┌─────────┐       ┌───────────┐      ┌───────────┐
   │ CNVKIT  │       │ CNVPYTOR  │      │ CLEAN_BAM │
   └────┬────┘       └─────┬─────┘      └─────┬─────┘
        │                  │                  ▼
        │                  │            ┌─────────────┐
        │                  │            │ READCOUNTER │
        │                  │            └──────┬──────┘
        │                  │                   ▼
        │                  │            ┌────────────┐
        │                  │            │  ICHORCNA  │
        │                  │            └──────┬─────┘
        │                  │                   │
        └──────────────────┴───────────────────┘
                            ▼
                     ┌─────────────┐
                     │ MERGE_CNVS  │  (standardize calls, merge overlaps,
                     └──────┬──────┘   filter centromere / no-gene regions)
                            ▼
                     ┌─────────────┐
                     │  ANNOTSV    │  (functional annotation)
                     └─────────────┘
```

**Tools used:**
- [CNVkit](https://cnvkit.readthedocs.io/) — read-depth based CNV caller
- [CNVpytor](https://github.com/abyzovlab/CNVpytor) — read-depth based CNV caller
- [ichorCNA](https://github.com/broadinstitute/ichorCNA) (via HMMcopy's `readCounter`) — CNV caller with tumor fraction estimation
- [AnnotSV](https://lbgi.fr/AnnotSV/) — structural variant annotation

## Why three callers?

Each caller has different sensitivity/specificity tradeoffs depending on
variant size, GC content, and mappability. Running all three and merging
overlapping/adjacent calls gives a higher-confidence unified call set than
any single tool, while still surfacing tool-specific calls (see the `Tool`
column in the output, e.g. `"1,3"` = called by CNVpytor and ichorCNA).

## Requirements

- [Nextflow](https://www.nextflow.io/) ≥ 22.10, DSL2
- Either:
  - **Conda** — two environments matching the tool names in `nextflow.config`
    (see `docker/environment-gatk_cd.yml` and `docker/environment-cnvkit.yml`
    for exact package lists), or
  - **Docker** — build the two images in `docker/` and run with `-profile docker`
    (see [Docker](#docker) below)
- Reference files (not included — see `params.example.yaml`):
  - hg38 reference FASTA
  - CNVkit flat reference (`.cnn`)
  - ichorCNA's GC/mappability wig files and centromere annotation (bundled with the [ichorCNA repo](https://github.com/broadinstitute/ichorCNA/tree/master/inst/extdata))
  - AnnotSV installed and its annotation resources downloaded

## Setup

1. Clone this repo.
2. Copy `params.example.yaml` → `params.yaml` and fill in paths for your environment.
3. Copy `samplesheet.example.csv` → `samplesheet.csv` and list your samples (`sample,bam`).
4. Update `params.conda_gatk_env` / `params.conda_cnvkit_env` in `nextflow.config`
   to point at your own conda environments.

## Usage

```bash
# with conda (default)
nextflow run main.nf -params-file params.yaml

# with Docker
nextflow run main.nf -params-file params.yaml -profile docker
```

Nextflow's built-in `-with-timeline`, `-with-report`, `-with-trace`, and
`-with-dag` outputs are enabled by default (see `nextflow.config`) and will
be written to `timeline.html`, `report.html`, `trace.txt`, and `dag.png`.

## Docker

Two images cover the two tool groups (matching the two conda envs):

```bash
docker build -f docker/gatk_cd.Dockerfile -t cnv-pipeline-gatk_cd:latest docker/
docker build -f docker/cnvkit.Dockerfile  -t cnv-pipeline-cnvkit:latest  docker/
```

Then run the pipeline with:

```bash
nextflow run main.nf -params-file params.yaml -profile docker
```

AnnotSV's annotation database (~15-20 GB) is intentionally not baked into the
image — download it once and bind-mount it at runtime. See
`docker/cnvkit.Dockerfile` for details.

## Testing / CI

`test-data/` holds tiny placeholder files (empty BAMs, a dummy centromere
bed) used only to validate the pipeline's wiring — channel joins, process
inputs/outputs, DSL2 syntax — without needing any of the real tools
installed:

```bash
nextflow run main.nf -profile test -stub-run
```

This works because every process has a `stub:` block (a `touch` of its
declared outputs) that Nextflow substitutes for the real `script:` when
`-stub-run` is passed. GitHub Actions runs this on every push/PR (see
`.github/workflows/ci.yml`), plus a second job that builds both Docker
images to catch Dockerfile rot.

This is *not* a scientific validation of the CNV calls themselves — see below.

## Output

For each sample, under `${output_dir}/${sample}/`:
- CNVkit: `.cns`, `.cnn`, scatter/diagram plots
- CNVpytor: `.pytor` root file, raw CNA calls
- ichorCNA: `.seg.txt`, `.cna.seg`, parameter estimates
- `${sample}_merged_cnvs.csv` — unified CNV calls across all three tools
- `${sample}_CNV.bed` — merged calls converted to AnnotSV input format
- `${sample}_annotSV.tsv` — AnnotSV functional annotation of the merged calls

`${sample}_merged_cnvs.csv` columns:

| column | description |
|---|---|
| `chrom`, `start`, `end` | genomic coordinates |
| `CN` | copy number |
| `CN_type` | `DEL` / `DUP` |
| `Tool` | which tool(s) called this region (`1`=CNVpytor, `2`=ichorCNA, `3`=CNVkit) |
| `size_kb`, `size_mb` | region size |

## Notes

- This is adapted from an internal clinical CNV-calling pipeline; scripts and
  parameters here reflect a general-purpose configuration and have had
  cohort-specific significance thresholds removed. Confirm thresholds and
  reference files suit your own use case before using this for anything
  clinical.

## Known limitations

- `CNVPYTOR`'s declared output filename is currently hardcoded to
  `*_T150KB_rawCNA.tsv` rather than interpolating `params.bin_size`. It works
  correctly as long as `bin_size` stays `50000` (the default); changing it
  requires updating `modules/cnvpytor.nf` to interpolate the bin size into
  the output declaration as well as the script.

## License

MIT — see [LICENSE](LICENSE).
