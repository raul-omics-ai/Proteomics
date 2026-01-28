#!/bin/bash

############################################################
# Name: proteomic_data_qc_script.sh
#
# Description:
#   Bash script to automate protein quantification
#   quality control using MultiQC with supported
#   proteomics software plugins.
#
# Supported software:
#   - maxquant   → --maxquant_plugin
#   - diann      → --diann_plugin
#   - quantms    → --quantms_plugin
#
# Usage:
#   protein_qc_multiqc.sh -s <software> -i <input_dir> -o <output_dir>
#
# Options:
#   -s    Protein quantification software (maxquant | diann | quantms)
#   -i    Input directory containing quantification results
#   -o    Output directory for MultiQC report
#   -h    Show this help message
#
############################################################

# Help function
usage() {
    echo "Usage: $0 -s <software> -i <input_dir> -o <output_dir>"
    echo
    echo "Options:"
    echo "  -s    Protein quantification software:"
    echo "        maxquant | diann | quantms"
    echo "  -i    Input directory with result files"
    echo "  -o    Output directory for MultiQC report"
    echo "  -h    Show this help message"
    echo
    exit 1
}

# Variables
SOFTWARE=""
INPUT_DIR=""
OUTPUT_DIR=""
PLUGIN=""

# Parse options
while getopts ":s:i:o:h" opt; do
    case ${opt} in
        s )
            SOFTWARE=$OPTARG
            ;;
        i )
            INPUT_DIR=$OPTARG
            ;;
        o )
            OUTPUT_DIR=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Check required arguments
if [[ -z "$SOFTWARE" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Error: missing required arguments."
    usage
fi

# Select MultiQC plugin based on software
case "$SOFTWARE" in
    maxquant)
        PLUGIN="--maxquant_plugin"
        ;;
    diann)
        PLUGIN="--diann_plugin"
        ;;
    quantms)
        PLUGIN="--quantms_plugin"
        ;;
    *)
        echo "Unsupported software: $SOFTWARE"
        echo "Supported options: maxquant, diann, quantms"
        exit 1
        ;;
esac

# Check input directory
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Create output directory if needed
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Output directory does not exist. Creating it..."
    mkdir -p "$OUTPUT_DIR"
fi

# Start message
echo ""
echo "Starting protein QC with MultiQC"
echo "Software : $SOFTWARE"
echo "Input    : $INPUT_DIR"
echo "Output   : $OUTPUT_DIR"
echo

# Run MultiQC
multiqc $PLUGIN "$INPUT_DIR" -o "$OUTPUT_DIR"

# Check exit status
if [[ $? -eq 0 ]]; then
    echo
    echo "Quality control analysis completed successfully."
    echo "Report available at: $OUTPUT_DIR"
else
    echo
    echo "Error occurred during MultiQC execution."
    exit 1
fi
