process CNVKIT {

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
	  path("*.call.cns"),
	  emit: merge_input

	path("*"),
	emit: all_outputs

    script:
    """

    	cnvkit.py batch ${bam} \
        -r ${params.cnvkit_reference} \
        --scatter \
        --diagram \
        -d ./
    """

    stub:
    """
    touch ${sample}.call.cns
    """
}
