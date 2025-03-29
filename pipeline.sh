#!/bin/bash

# ===============================================================================
# Gene Prediction and Annotation Pipeline v1.2
#
# A modular pipeline for bacterial genome analysis including:
# 1. Gene prediction and functional annotation (Prodigal + Prokka)
# 2. Ribosomal RNA detection (Barrnap)
# 3. Gene prediction and functional annotation (Glimmer + EggNOG)
# 4. Homology-based gene prediction and profiling (GeMoMa + HMMER)
# ===============================================================================

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure
shopt -s nullglob

# ========================== CONFIGURATION OPTIONS ==============================

INPUT_DIR="${1:-./input_fasta}"  # Directory containing input FASTA files
OUTPUT_DIR="${2:-./output_annotation}"  # Directory for output files
THREADS="${3:-8}"  # Default number of CPU threads

# Performance metrics file
METRICS_FILE="${OUTPUT_DIR}/performance_metrics.tsv"

# Define Conda environment names for each part
ENV_PRODIGAL_PROKKA="env_prodigal_prokka"
ENV_BARRNAP="env_barrnap"
ENV_GLIMMER_EGGNOG="env_glimmer_eggnog"
ENV_GEMOMA_HMMER="env_gemoma_hmmer"

# ========================== FUNCTIONS =========================================

# Logging function
log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$log_file"
}

# Error handling function
handle_error() {
    local exit_code=$1
    local line_no=$2
    local command=$3
    log "ERROR" "Command failed with exit code $exit_code at line $line_no: $command"
    exit $exit_code
}

# Trap errors
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# Check if a command exists
check_command() {
    local cmd=$1
    if ! command -v $cmd &> /dev/null; then
        log "ERROR" "Required command not found: $cmd"
        exit 1
    fi
}

# Check system resources
check_resources() {
    local required_memory=16  # GB
    local available_memory=$(free -g | awk '/^Mem:/{print $7}')
    
    if [ $available_memory -lt $required_memory ]; then
        log "WARNING" "Available memory ($available_memory GB) is less than recommended ($required_memory GB)"
    fi
    
    # Check disk space
    local required_space=50  # GB
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ $available_space -lt $required_space ]; then
        log "WARNING" "Available disk space ($available_space GB) is less than recommended ($required_space GB)"
    fi
}

# ========================== INITIALIZATION =====================================

usage() {
    echo "Usage: $0 [INPUT_DIR] [OUTPUT_DIR] [THREADS]"
    echo ""
    echo "Arguments:"
    echo "  INPUT_DIR      Directory containing input FASTA files (default: ./input_fasta)"
    echo "  OUTPUT_DIR     Directory for output files (default: ./output_annotation)"
    echo "  THREADS        Number of CPU threads to use (default: 8)"
    exit 1
}

# Validate input
if [ ! -d "$INPUT_DIR" ]; then
    log "ERROR" "Input directory not found: ${INPUT_DIR}"
    usage
fi

# Create output directories
mkdir -p "${OUTPUT_DIR}/logs" "${OUTPUT_DIR}/Prodigal_Prokka" "${OUTPUT_DIR}/Barrnap" \
         "${OUTPUT_DIR}/Glimmer_EggNOG" "${OUTPUT_DIR}/GeMoMa_HMMER"

LOG_DIR="${OUTPUT_DIR}/logs"
log_file="${LOG_DIR}/pipeline_$(date +%Y%m%d_%H%M%S).log"

# Check system resources
check_resources

# ========================== CONDA ENVIRONMENT SETUP ===========================

create_env() {
    local env_name="$1"
    shift
    local packages="$@"

    if ! conda env list | grep -q "$env_name"; then
        log "INFO" "Creating Conda environment: $env_name"
        conda create -n "$env_name" -c bioconda -c conda-forge $packages -y
    else
        log "INFO" "Conda environment $env_name already exists"
    fi
}

activate_env() {
    local env_name="$1"
    log "INFO" "Activating Conda environment: $env_name"
    eval "$(conda shell.bash hook)"
    conda activate "$env_name"
}

deactivate_env() {
    log "INFO" "Deactivating Conda environment"
    conda deactivate
}

# Create environments for each part of the pipeline
log "INFO" "Setting up Conda environments..."
create_env "$ENV_PRODIGAL_PROKKA" prodigal prokka bioperl perl-xml-simple
create_env "$ENV_BARRNAP" barrnap bedtools
create_env "$ENV_GLIMMER_EGGNOG" glimmer eggnog-mapper biopython emboss
create_env "$ENV_GEMOMA_HMMER" gemoma hmmer perl-xml-simple blast

# ========================== PART 1: PRODIGAL + PROKKA ==========================

log "INFO" "Starting Part 1: Prodigal + Prokka"
activate_env "$ENV_PRODIGAL_PROKKA"

for file in "${INPUT_DIR}"/*.fasta; do
    BASENAME=$(basename "$file" .fasta)
    PRODIGAL_OUTDIR="${OUTPUT_DIR}/Prodigal_Prokka/${BASENAME}"
    mkdir -p "${PRODIGAL_OUTDIR}"
    
    log "INFO" "Processing ${BASENAME} with Prodigal..."
    prodigal -i "$file" -c -m -f gbk \
             -o "${PRODIGAL_OUTDIR}/${BASENAME}_genes.gbk" \
             -d "${PRODIGAL_OUTDIR}/${BASENAME}_cds.fna" \
             -a "${PRODIGAL_OUTDIR}/${BASENAME}_proteins.faa"

    log "INFO" "Processing ${BASENAME} with Prokka..."
    prokka --outdir "$PRODIGAL_OUTDIR" --prefix "$BASENAME" --force --cpus "$THREADS" --kingdom Bacteria "$file"
done

deactivate_env

# ========================== PART 2: BARRNAP ====================================

log "INFO" "Starting Part 2: Barrnap"
activate_env "$ENV_BARRNAP"

for file in "${INPUT_DIR}"/*.fasta; do
    BASENAME=$(basename "$file" .fasta)
    BARRNAP_OUTDIR="${OUTPUT_DIR}/Barrnap/${BASENAME}"
    mkdir -p "${BARRNAP_OUTDIR}"
    
    log "INFO" "Processing ${BASENAME} with Barrnap..."
    barrnap --kingdom bac --outseq "${BARRNAP_OUTDIR}/${BASENAME}_16S.fa" "$file" > "${BARRNAP_OUTDIR}/${BASENAME}_Barrnap.gff"
done

deactivate_env

# ========================== PART 3: GEMOMA + HMMER =============================

log "INFO" "Starting Part 3: GeMoMa + HMMER"
activate_env "$ENV_GEMOMA_HMMER"

# Create reference directory
mkdir -p "${OUTPUT_DIR}/ref"

# Download reference genome if needed
REFERENCE_GENOME="${OUTPUT_DIR}/ref/GCF_000008805.1_ASM880v1_genomic.fna"
REFERENCE_GFF="${OUTPUT_DIR}/ref/GCF_000008805.1_ASM880v1_genomic.gff"

if [ ! -f "${REFERENCE_GENOME}" ]; then
    log "INFO" "Downloading reference genome..."
    wget -O "${REFERENCE_GENOME}.gz" \
        "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/008/805/GCF_000008805.1_ASM880v1/GCF_000008805.1_ASM880v1_genomic.fna.gz"
    gunzip "${REFERENCE_GENOME}.gz"
fi

if [ ! -f "${REFERENCE_GFF}" ]; then
    log "INFO" "Downloading reference GFF..."
    wget -O "${REFERENCE_GFF}.gz" \
        "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/008/805/GCF_000008805.1_ASM880v1/GCF_000008805.1_ASM880v1_genomic.gff.gz"
    gunzip "${REFERENCE_GFF}.gz"
fi

for file in "${INPUT_DIR}"/*.fasta; do
    BASENAME=$(basename "$file" .fasta)
    GEMOMA_OUTDIR="${OUTPUT_DIR}/GeMoMa_HMMER/${BASENAME}"
    mkdir -p "${GEMOMA_OUTDIR}"
    
    log "INFO" "Processing ${BASENAME} with GeMoMa..."
    GeMoMa GeMoMaPipeline g="$REFERENCE_GENOME" a="$REFERENCE_GFF" t="$file" \
        outdir="$GEMOMA_OUTDIR" \
        AnnotationFinalizer.p="GENE_PREFIX" \
        AnnotationFinalizer.i="G" \
        AnnotationFinalizer.s="0" \
        AnnotationFinalizer.d=5

    log "INFO" "Processing ${BASENAME} with HMMER..."
    hmmscan --domtblout "${GEMOMA_OUTDIR}/${BASENAME}_hmmer_results.tbl" \
        Pfam-A.hmm "${GEMOMA_OUTDIR}/${BASENAME}_proteins.faa"
done

deactivate_env

# ========================== PART 4: GLIMMER + EGGNOG ==========================

log "INFO" "Starting Part 4: Glimmer + EggNOG"
activate_env "$ENV_GLIMMER_EGGNOG"

# Download and prepare reference genome
REFERENCE_GENOME="GCF_000009085.1_ASM908v1_genomic.fna"
if [ ! -f "$REFERENCE_GENOME" ]; then
    log "INFO" "Downloading reference genome for Glimmer..."
    wget -O "${REFERENCE_GENOME}.gz" \
        "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/009/085/GCF_000009085.1_ASM908v1/${REFERENCE_GENOME}.gz"
    gunzip -v "${REFERENCE_GENOME}.gz"
fi

# Train Glimmer model
log "INFO" "Training Glimmer model..."
long-orfs -n -t 1.15 "$REFERENCE_GENOME" type_strain_genome.longorfs
extract -t "$REFERENCE_GENOME" type_strain_genome.longorfs > type_strain_genome.train
build-icm -r type_strain_genome.icm < type_strain_genome.train

# Process each input file
for file in "${INPUT_DIR}"/*.fasta; do
    BASENAME=$(basename "$file" .fasta)
    output_dir="${OUTPUT_DIR}/Glimmer_EggNOG/${BASENAME}"
    mkdir -p "$output_dir"
    
    log "INFO" "Processing ${BASENAME} with Glimmer..."
    glimmer3 -o 30 -g 150 -t 50 "$file" type_strain_genome.icm "${output_dir}/${BASENAME}"
    
    log "INFO" "Processing ${BASENAME} with EggNOG..."
    emapper.py -i "${output_dir}/${BASENAME}.predict" -o "${output_dir}/${BASENAME}_eggnog" --cpu "$THREADS"
done

deactivate_env

# ========================== FINALIZATION ======================================

log "INFO" "Pipeline completed successfully!"
log "INFO" "Results are available in: ${OUTPUT_DIR}"
