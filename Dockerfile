# Use a specific version of Mambaforge base image
FROM condaforge/mambaforge:4.13.0-1

# Add labels for better documentation
LABEL maintainer="Sanya Badole <sbadole6@gatech.edu>"
LABEL version="1.0"
LABEL description="Docker image for D2 Gene Prediction and Annotation Pipeline"

# Set working directory
WORKDIR /app

# Install system packages
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    perl \
    bedtools \
    emboss \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash pipeline_user

# Create and set permissions for required directories
RUN mkdir -p /app/input_fasta /app/output_annotation && \
    chown -R pipeline_user:pipeline_user /app

# Switch to non-root user
USER pipeline_user

# Create Conda environments with specific versions for reproducibility
RUN mamba create -n env_prodigal_prokka -c bioconda -c conda-forge \
    prodigal=2.6.3 \
    prokka=1.14.6 \
    perl-xml-simple=2.25 \
    perl-bioperl=1.7.8 -y && \
    mamba create -n env_barrnap -c bioconda -c conda-forge \
    barrnap=0.9 \
    bedtools=2.30.0 -y && \
    mamba create -n env_glimmer_eggnog -c bioconda -c conda-forge \
    eggnog-mapper=2.1.9 \
    diamond=2.0.15 \
    biopython=1.79 \
    emboss=6.6.0 \
    gffread=0.12.7 -y && \
    mamba create -n env_gemoma_hmmer -c bioconda -c conda-forge \
    gemoma=1.9 \
    hmmer=3.3.2 \
    mmseqs2=14.7e284 \
    blast=2.12.0 \
    openjdk=8 \
    perl-xml-simple \
    python=3.7 -y && \
    mamba clean -afy

# Copy pipeline script and set permissions
COPY --chown=pipeline_user:pipeline_user pipeline.sh /app/pipeline.sh
RUN chmod +x /app/pipeline.sh

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD ps aux | grep pipeline.sh || exit 1

# Set environment variables
ENV PATH="/opt/conda/envs/env_prodigal_prokka/bin:/opt/conda/envs/env_barrnap/bin:/opt/conda/envs/env_glimmer_eggnog/bin:/opt/conda/envs/env_gemoma_hmmer/bin:${PATH}"

# Set entrypoint
ENTRYPOINT ["/bin/bash", "/app/pipeline.sh"]
