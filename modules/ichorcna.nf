process ICHORCNA {

    tag "$sample"

    publishDir { "${params.output_dir}/${sample}" },
               mode: 'copy'

    cpus 8
    memory '64 GB'

    input:
    tuple val(sample),
          path(wig)

    output:
    tuple val(sample),
      path("*.seg.txt"),
      emit: merge_input

    tuple val(sample),
      path("*.cna.seg"),
      emit: plot_input


     path("*"),
	emit: all_outputs

    script:
    """

    Rscript ${params.ichorcna_script} \
        --id ${sample}_T2${params.bin_size/1000}KB \
        --WIG ${wig} \
	--genomeBuild hg38 \
	--genomeStyle UCSC \
        --ploidy "c(2)" \
        --normal "c(0.5)" \
        --maxCN 5 \
        --gcWig ${params.ichorcna_gc_wig} \
	--mapWig ${params.ichorcna_map_wig} \
	--centromere ${params.ichorcna_centromere} \
	--includeHOMD FALSE \
	--chrs 'c(1:22,"X","Y")' \
	--chrTrain 'c(1:22)' \
	--estimateNormal FALSE \
	--estimatePloidy FALSE \
	--estimateScPrevalence FALSE \
	--outDir ./
    """

    stub:
    """
    touch ${sample}_T2${params.bin_size/1000}KB.seg.txt
    touch ${sample}_T2${params.bin_size/1000}KB.cna.seg
    """
}
