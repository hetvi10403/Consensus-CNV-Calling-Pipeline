# Image for: INDEX_BAM, CLEAN_BAM, CNVPYTOR, READCOUNTER, ICHORCNA, MERGE_CNVS
#
# Build:
#   docker build -f docker/gatk_cd.Dockerfile -t cnv-pipeline-gatk_cd:latest docker/
#
# All tools here (samtools, cnvpytor, hmmcopy's readCounter, r-ichorcna) are
# installed from bioconda. ichorCNA's scripts/ directory (runIchorCNA.R and
# friends) is not part of the conda R package, so it's pulled separately
# from the ichorCNA GitHub repo.

FROM mambaorg/micromamba:1.5.8

COPY --chown=$MAMBA_USER:$MAMBA_USER environment-gatk_cd.yml /tmp/environment.yml

RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

ARG MAMBA_DOCKERFILE_ACTIVATE=1

# Workaround for a bug in cnvpytor 1.3.2 (bioconda): genome.py's
# download_resources() calls res.split("/") but res is a PosixPath,
# not a str, so it crashes with AttributeError. Fixed upstream on
# GitHub master but not yet released to bioconda.
RUN sed -i 's/fn = res\.split("\/")\[-1\]/fn = str(res).split("\/")[-1]/g' \
    /opt/conda/lib/python3.13/site-packages/cnvpytor/genome.py && \
    micromamba run -n base cnvpytor -download

USER root
RUN git clone --depth 1 https://github.com/broadinstitute/ichorCNA.git /tmp/ichorCNA && \
    mkdir -p /opt/ichorCNA && \
    cp -r /tmp/ichorCNA/scripts /opt/ichorCNA/scripts && \
    rm -rf /tmp/ichorCNA
USER $MAMBA_USER

# runIchorCNA.R:        /opt/ichorCNA/scripts/runIchorCNA.R
# gc/map wig + centromere ship inside the conda R package's extdata dir, e.g.
#   /opt/conda/lib/R/library/ichorCNA/extdata/gc_hg38_50kb.wig
#   /opt/conda/lib/R/library/ichorCNA/extdata/map_hg38_50kb.wig
#   /opt/conda/lib/R/library/ichorCNA/extdata/GRCh38.GCA_000001405.2_centromere_acen.txt
# Point params.ichorcna_* at these paths when running with -profile docker.

ENV PATH="/opt/conda/bin:$PATH"
