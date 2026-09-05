process CLEAN_BAM {
	
	tag "$sample"

	publishDir { "${params.output_dir}/${sample}" },
		mode: 'copy'

	cpus 4
	memory '16 GB'

	input:
	tuple val(sample),
	      path(bam),
	      path(bai)
	
	output:
	tuple val(sample),
	      path("${sample}.clean.bam"),
	      path("${sample}.clean.bam.bai")
	
	script:
	"""

	samtools view -H ${bam} > header.txt
	
	sed -i 's/\\\\tDS:[^ \\\\t]*//g' header.txt
	
	samtools reheader \
	header.txt \
	${bam} \
	> ${sample}.clean.bam 

	samtools index ${sample}.clean.bam
	"""

	stub:
	"""
	touch ${sample}.clean.bam ${sample}.clean.bam.bai
	"""

  }

	
	
