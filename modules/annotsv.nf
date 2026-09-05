process ANNOTSV {

    tag "$sample"

    publishDir { "${params.output_dir}/${sample}" },
        mode: 'copy'

    cpus 2
    memory '8 GB'

    input:
    tuple val(sample),
          path(merged_cnvs)

    output:
    tuple val(sample),
          path("${sample}_CNV.bed"),
          path("${sample}_annotSV.tsv")

    script:
    """
    python3 ${projectDir}/bin/cnv_to_bed.py \
        --input ${merged_cnvs} \
        --sample ${sample} \
        --output ${sample}_CNV.bed

    ${params.annotsv_bin} \
        -SVinputFile ${sample}_CNV.bed \
        -outputFile ${sample}_annotSV.tsv \
        -svtBEDcol 4 \
        -samplesidBEDcol 5
    """

    stub:
    """
    touch ${sample}_CNV.bed ${sample}_annotSV.tsv
    """
}
