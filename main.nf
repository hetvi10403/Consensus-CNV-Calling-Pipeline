nextflow.enable.dsl = 2

include { CNV_WORKFLOW } from './workflows/cnv_workflow'

workflow {

	CNV_WORKFLOW()
}
