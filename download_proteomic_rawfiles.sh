#!/bin/bash
# ------------------------------------------------------------------------------
# download_pride_raws.sh
#
# Descritpion:
#    Downloads all .raw files from a PRIDE project directory (FTP/HTTPS),
#    and additionally downloads the cRAP contaminant FASTA database from
#    TheGPM.

#
# Features:
#   - Takes a PRIDE URL and an output directory as arguments
#   - Creates an intermediate accession list (AccList.txt)
#   - Downloads each .raw file sequentially
#   - Shows a clean progress output on screen
#   - Stores all wget verbosity in a log file (download.log)
#   - Skips files that already exist
#   - Automatically downloads the cRAP contaminant FASTA and renames it to:
#     contaminants.fasta
#
#
# Usage:
#   ./download_pride_raws.sh -u <PRIDE_URL> -o <OUTPUT_DIR>
#
# Example:
#   ./download_pride_raws.sh \
#     -u https://ftp.pride.ebi.ac.uk/pride/data/archive/2026/10/PXD123456789/ \
#     -o ./raw_data
#
# Files generated inside OUTPUT_DIR:
#   - AccList.txt        → list of detected .raw files on the server
#   - contaminants.fasta → cRAP contaminant FASTA downloaded from TheGPM
#   - download.log       → detailed wget log of all downloads

# ------------------------------------------------------------------------------

set -euo pipefail

usage() {
    echo "Usage: $0 -u <PRIDE_URL> -o <OUTPUT_DIR>"
    echo
    echo "Example:"
    echo "  $0 -u https://ftp.pride.ebi.ac.uk/pride/data/archive/2024/10/PXD052549/ -o ./raw_data"
    exit 1
}

URL=""
OUTDIR=""

# Parse command-line options
while getopts ":u:o:h" opt; do
    case $opt in
        u) URL="$OPTARG" ;;
        o) OUTDIR="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Validate arguments
if [[ -z "$URL" || -z "$OUTDIR" ]]; then
    usage
fi

# Prepare output directory
mkdir -p "$OUTDIR"

ACC_LIST="$OUTDIR/AccList.txt"
LOGFILE="$OUTDIR/download.log"


# --- Download cRAP contaminants FASTA and save as contaminants.fasta ---
CRAP_DIR="ftp://ftp.thegpm.org/fasta/cRAP"
CRAP_OUT="$OUTDIR/contaminants.fasta"

echo "[INFO] Downloading cRAP contaminants FASTA → $CRAP_OUT"

wget -q -O "$CRAP_OUT" "$CRAP_DIR/cRAP.fasta"


echo "[INFO] Exploring PRIDE repository"
echo "       $URL"
echo "[INFO] Generating .raw file list → $ACC_LIST"

# Retrieve directory listing and extract .raw filenames
wget -qO- "$URL" \
| grep -o 'href="[^"]*\.raw"' \
| sed 's/href="//;s/"//' > "$ACC_LIST"

N=$(wc -l < "$ACC_LIST")

if [[ "$N" -eq 0 ]]; then
    echo "[ERROR] No .raw files found at the provided URL."
    exit 2
fi

echo "[INFO] Found $N .raw files"
echo "[INFO] Downloading into: $OUTDIR"
echo "[INFO] Detailed log: $LOGFILE"
echo

# Download loop
i=1
while read -r f; do
    TARGET="$OUTDIR/$f"

    if [[ -f "$TARGET" ]]; then
        echo "[$i/$N] ALREADY EXISTS: $f"
    else
        echo "[$i/$N] DOWNLOADING: $f"
        if wget -c \
                --progress=bar:force:noscroll \
                -P "$OUTDIR" "${URL}${f}" >> "$LOGFILE" 2>&1; then
            echo "[$i/$N] OK: $f"
        else
            echo "[$i/$N] ERROR: $f (see log)"
        fi
    fi

    ((i++))
done < "$ACC_LIST"

echo
echo "[INFO] Process finished."
