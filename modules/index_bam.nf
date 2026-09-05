process INDEX_BAM {
	
	tag "$sample"

	publishDir { "${params.output_dir}/${sample}" },
		mode: 'copy'


	cpus 4
	memory '8 GB'

	input:
	tuple val(sample), path(bam)
	
	output:
	tuple val(sample),
	      path(bam),
 	      path("${bam}.bai")

	script:
	"""

	samtools index ${bam}
	"""

	stub:
	"""
	touch ${bam}.bai
	"""

  }
 
