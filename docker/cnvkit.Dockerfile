# Image for: CNVKIT, ANNOTSV
#
# Build:
#   docker build -f docker/cnvkit.Dockerfile -t cnv-pipeline-cnvkit:latest docker/
#
# AnnotSV's annotation resources (~15-20 GB) are intentionally NOT baked into
# this image (that's also AnnotSV upstream's own recommendation, since the
# annotation data changes independently of the tool version). Download them
# once on the host and bind-mount into the container at runtime:
#
#   docker run -v /path/to/AnnotSV/share:/opt/conda/share/AnnotSV ...
#
# See: https://github.com/lgmgeo/AnnotSV#installation

FROM mambaorg/micromamba:1.5.8

COPY --chown=$MAMBA_USER:$MAMBA_USER environment-cnvkit.yml /tmp/environment.yml

RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
