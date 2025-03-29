# Gene Prediction and Annotation Pipeline

A comprehensive pipeline for bacterial genome analysis that combines multiple gene prediction and annotation tools to provide robust results.

## Overview

This pipeline integrates multiple tools for gene prediction and annotation:
1. Prodigal + Prokka for primary gene prediction and annotation
2. Barrnap for ribosomal RNA detection
3. GeMoMa + HMMER for homology-based gene prediction and profiling
4. Glimmer + EggNOG for additional gene prediction and functional annotation

## Requirements

- **CPU**: x86_64 architecture recommended
- **OS**: Linux (Tested on Ubuntu 22.04 LTS)
- **Memory**: Minimum 16GB RAM (32GB recommended for large datasets)
- **Storage**: 50GB+ free space for temporary files and database downloads
- **Docker**: Docker installed on your system

## Installation

### Clone the Repository

```bash
git clone https://github.gatech.edu/Gene-Prediction-and-Annotation
```

### Docker Setup

1. Build the Docker image:
```bash
docker build -t genome_pipeline_docker .
```

2. Create the required directory structure:
```bash
mkdir -p input_fasta output_annotation
```

## Directory Structure

```
Gene Prediction and Annotation Folder/
├── input_fasta/                # Place your input FASTA files here
├── output_annotation/          # Results will be stored here
│   ├── Barrnap/               # Barrnap results
│   ├── GeMoMa_HMMER/          # GeMoMa and HMMER results
│   ├── Glimmer_EggNOG/        # Glimmer and EggNOG results
│   ├── Prodigal_Prokka/       # Prodigal and Prokka results
│   └── logs/                  # Pipeline execution logs
├── pipeline.sh                # Main pipeline script
└── Dockerfile                 # Docker configuration
```

## Usage

1. Place your input FASTA files in the `input_fasta` directory.

2. Run the pipeline using Docker:
```bash
docker run -it \
  -v "$(pwd)/pipeline.sh:/app/pipeline.sh" \
  -v "$(pwd)/input_fasta:/app/input_fasta" \
  -v "$(pwd)/output_annotation:/app/output_annotation" \
  genome_pipeline_docker /app/input_fasta /app/output_annotation 8
```

The last parameter (8) specifies the number of CPU threads to use.

## Pipeline Components

### 1. Prodigal + Prokka
- **Prodigal**: Ab initio gene prediction tool optimized for bacterial genomes
- **Prokka**: Rapid prokaryotic genome annotation tool
- **Output**: Predicted genes with functional annotations

### 2. Barrnap
- **Purpose**: Predicts ribosomal RNA (rRNA) genes
- **Features**: 
  - Supports bacterial, archaeal, and eukaryotic genomes
  - Uses Hidden Markov Models for accurate prediction
- **Output**: rRNA gene locations in GFF format

### 3. GeMoMa + HMMER
- **GeMoMa**: Homology-based gene prediction
- **HMMER**: Protein domain annotation using profile hidden Markov models
- **Output**: Homology-based gene predictions with functional annotations

### 4. Glimmer + EggNOG
- **Glimmer**: Gene prediction using interpolated Markov models
- **EggNOG**: Functional annotation using orthology assignments
- **Output**: Additional gene predictions with functional annotations

## Technical Requirements

### System Resources
- **CPU**: Multi-core processor recommended
- **Memory**: 16GB minimum (32GB recommended)
- **Storage**: 50GB+ free space
- **Network**: Stable internet connection for database downloads

### Software Dependencies
- Docker
- Conda/Mamba (handled within Docker)
- Various bioinformatics tools (automatically installed in Docker)

## Output Files

The pipeline generates several output files for each input genome:
- Gene predictions in various formats (GFF, GBK, FASTA)
- Functional annotations
- rRNA predictions
- Protein domain annotations
- Orthology assignments

All results are organized in sample-specific directories under `output_annotation/`.

## Troubleshooting

1. **Docker Issues**
   - Ensure Docker is running
   - Check Docker permissions
   - Verify sufficient disk space

2. **Memory Issues**
   - Reduce the number of threads
   - Process smaller genomes first
   - Monitor system resources

3. **Database Issues**
   - Check internet connection
   - Verify sufficient disk space
   - Ensure proper permissions

## Contributing

Please submit issues and pull requests through the GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
