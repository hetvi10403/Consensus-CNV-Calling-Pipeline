# Test data

# Test data

`sample1.bam` / `sample2.bam` are empty placeholder files that exist only so
`-profile test -stub-run` has something to point at for staging. They are
NOT real sequencing data: in stub mode Nextflow substitutes each process's
`stub:` block (simple `touch` commands) for the real script, so BAM content
never matters here, only that the paths declared in the sample sheet exist
for staging.

The centromere filter uses the real, small `resources/centromere_plus_nogenes.bed`
bundled in the repo — no dummy needed there.

This validates the DSL2 wiring (channels, joins, process I/O) on every push
without needing samtools/CNVkit/CNVpytor/ichorCNA/AnnotSV installed.

For a real functional/scientific validation run, replace the BAMs with
actual (ideally small, subsetted) sequencing data and drop `-stub-run` — see
the main README's "Validation" section.

