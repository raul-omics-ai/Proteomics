
# 🧬 Proteomics Bash Tools

This directory contains automated Bash scripts for the initial management and quality control of proteomics data. These tools are designed to streamline raw data acquisition from PRIDE repositories and generate standardized quality control (QC) reports using MultiQC.

---

## 📁 Contents

### **1. `download_proteomic_rawfiles.sh`**
This script automates the download of **.raw** files from PRIDE (FTP/HTTPS) project directories.

#### ✅ Features
- Downloads all `.raw` files found in a PRIDE repository URL.
- Automatically generates:
  - `AccList.txt` → List of detected `.raw` files.
  - `download.log` → Detailed log with wget output.
  - `contaminants.fasta` → cRAP contaminants FASTA from TheGPM.
- Skips files that already exist.
- Shows a clean progress bar.

#### 📌 Usage
```bash
./download_proteomic_rawfiles.sh -u <PRIDE_URL> -o <OUTPUT_DIR>
```

#### 📌 Example
```bash
./download_proteomic_rawfiles.sh   -u https://ftp.pride.ebi.ac.uk/pride/data/archive/2026/10/PXD123456/   -o ./raw_data
```

---

### **2. `proteomic_data_qc_script.sh`**
This script automates QC analysis for protein quantification results using **MultiQC**.

#### ✅ Supported software
- **MaxQuant** → `--maxquant_plugin`
- **DIA-NN** → `--diann_plugin`
- **quantMS** → `--quantms_plugin`

#### ✅ Features
- Runs MultiQC on quantification outputs.
- Generates a unified QC HTML report.
- Produces a comprehensive CSV file (`QC_metrics_description.csv`) describing:
  - Experimental design and parameter summaries
  - Identification statistics (peptides, proteins, MS/MS rates)
  - Contaminant levels
  - Missed cleavages
  - Mass error distributions
  - Intensity distributions
  - PCA and sample-level QC metrics
  - Chromatography-related metrics (RT, peak width, TopN behavior)

#### 📌 Usage
```bash
./proteomic_data_qc_script.sh -s <software> -i <input_dir> -o <output_dir>
```

#### 📌 Example
```bash
./proteomic_data_qc_script.sh   -s maxquant   -i ./maxquant_output   -o ./qc_report
```

#### 📌 Options
| Option | Description |
|--------|-------------|
| `-s` | Software used: `maxquant`, `diann`, `quantms` |
| `-i` | Input directory containing result files |
| `-o` | Output directory for QC report |
| `-h` | Display help message |

---

## ✅ Requirements

### For `download_proteomic_rawfiles.sh`
- Linux/macOS
- `wget`
- `grep`, `sed`, `wc`
- Internet access for FTP/HTTPS

### For `proteomic_data_qc_script.sh`
- MultiQC installed
- Appropriate plugins (MaxQuant, DIA-NN, quantMS)
- Bash ≥ 4.0

---

## ✅ Notes
- Both scripts include argument validation and error handling.
- Log files are generated automatically for reproducibility.
- These scripts can be integrated into workflow managers such as Nextflow or Snakemake.

---

## ✨ Author
**Raul Fernandez Contreras**

