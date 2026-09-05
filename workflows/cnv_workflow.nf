include { INDEX_BAM } from '../modules/index_bam'
include { CLEAN_BAM } from '../modules/clean_bam'
include { CNVPYTOR } from '../modules/cnvpytor'
include { CNVKIT } from '../modules/cnvkit'
include { READCOUNTER } from '../modules/readcounter'
include { ICHORCNA } from '../modules/ichorcna'
include { MERGE_CNVS } from '../modules/merge_cnvs'
include { ANNOTSV } from '../modules/annotsv'

workflow CNV_WORKFLOW {

	// sample channel

	samples_ch = Channel
	.fromPath(params.sample_sheet)
	.splitCsv(header:true)
	.map { row ->

    	tuple(
        row.sample,
        file(row.bam)
    	)
	}

	// Index BAMs

	indexed_bam_ch = INDEX_BAM(samples_ch)

	// CNVpytor branch

	CNVPYTOR(indexed_bam_ch)
	cnvpytor_ch = CNVPYTOR.out.merge_input

	// CNVkit branch

	CNVKIT(indexed_bam_ch)
	cnvkit_ch = CNVKIT.out.merge_input

	// ichorCNA branch

	cleaned_bam_ch = CLEAN_BAM(indexed_bam_ch)

	wig_ch = READCOUNTER(cleaned_bam_ch)

	ICHORCNA(wig_ch)

	ichorcna_ch = ICHORCNA.out.merge_input

	// Unified merge (per-tool significance thresholds removed;
	// centromere/no-gene filter retained via ichorCNA's centromere annotation)

	merged_input = cnvpytor_ch
    		      .join(ichorcna_ch)
                      .join(cnvkit_ch)

	MERGE_CNVS(
		merged_input,
		file(params.centromere)
	)

	// AnnotSV annotation on the unified CNV calls

	ANNOTSV(MERGE_CNVS.out.merge_output)
}
