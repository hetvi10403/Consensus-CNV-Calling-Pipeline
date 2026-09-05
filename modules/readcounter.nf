process READCOUNTER {

    tag "$sample"

    publishDir { "${params.output_dir}/${sample}" },
               mode: 'copy'

    cpus 8
    memory '32 GB'

    input:
    tuple val(sample),
          path(clean_bam),
          path(clean_bai)

    output:
    tuple val(sample),
          path("${sample}_T2${params.bin_size/1000}KB.wig")

    script:
    """
    ${params.readcounter_bin} \
        --window ${params.bin_size} \
        --quality 20 \
	--chromosome "chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chrX,chrY" \
        ${clean_bam} \
        > ${sample}_T2${params.bin_size/1000}KB.wig
    """

    stub:
    """
    touch ${sample}_T2${params.bin_size/1000}KB.wig
    """
}
