	process CNVPYTOR {
	
	tag "$sample"
	publishDir { "${params.output_dir}/${sample}" },
		mode: 'copy'
	
	cpus 8
	memory '32 GB'

	input:
	tuple val(sample),
	      path(bam),
	      path(bai)

	output:
	tuple val(sample),
      	path("${sample}_T150KB_rawCNA.tsv"),
	emit: merge_input

	path("*"),
	emit: all_outputs
	
	script:
	"""

    cnvpytor \
        -root ${sample}_T1${params.bin_size/1000}KB.pytor \
        -chrom chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 \
               chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 \
               chr19 chr20 chr21 chr22 chrX chrY \
        -rd ${bam} \
        -his ${params.bin_size} \
        -partition ${params.bin_size} \
        -call ${params.bin_size} \
        > ${sample}_T1${params.bin_size/1000}KB_rawCNA.tsv
    """

    stub:
    """
    touch ${sample}_T150KB_rawCNA.tsv
    """
}	
	
