process MERGE_CNVS {

    tag "$sample"

    publishDir { "${params.output_dir}/${sample}" },
    mode: 'copy'

    input:
    tuple val(sample),
          path(tool1),
          path(tool2),
          path(tool3)
    path(centromere)

    output:
    tuple val(sample),
          path("${sample}_merged_cnvs.csv"),
          emit: merge_output

    script:
    """
    python3 ${projectDir}/bin/merge_cnvs.py \
        --sample ${sample} \
        --tool1 ${tool1} \
        --tool2 ${tool2} \
        --tool3 ${tool3} \
        --centromere ${centromere}
    """

    stub:
    """
    touch ${sample}_merged_cnvs.csv
    """
}
