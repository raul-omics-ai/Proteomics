# Automatic Proteomic Analysis Pipeline

## Overview
This repository contains an R function (`auto_proteomic_analysis`) designed to perform a fully automated downstream analysis of label-free quantitative (LFQ) proteomics data.

The pipeline integrates data processing, quality control, statistical analysis, and visualization into a single workflow, primarily leveraging the **DEP** package.

---

## Features
- 📂 Import of proteomics data (MS2, peptides, proteinGroups)
- 🧹 Filtering of contaminants and decoys
- 🔍 Quality control (QC) metrics and visualizations
- 🧬 Missing value handling and imputation
- 📊 Normalization using VSN
- 📈 Differential abundance analysis (limma-based)
- 🔥 Publication-ready plots (PCA, heatmaps, volcano plots, etc.)
- 📑 Automated Excel report generation

---

## Requirements

### R packages
The function will automatically install missing packages, but it relies on:

- DEP
- ggplot2
- dplyr
- tidyr
- SummarizedExperiment
- patchwork
- pheatmap
- openxlsx
- RColorBrewer

---

## Input Files

You need the following input files:

- **MS2 (evidence.txt)**
- **Peptides (peptides.txt)**
- **Protein groups (proteinGroups.txt)**
- **Metadata table** with required columns:
  - `label`
  - `condition`
  - `replicate`

---

## Usage

```r
auto_proteomic_analysis(
  ms2_file_path = "path/to/evidence.txt",
  peptide_file_path = "path/to/peptides.txt",
  proteinGroup_file_path = "path/to/proteinGroups.txt",
  metadata = metadata_df,
  where_to_save = "results/",
  title = "Proteomic_Analysis",
  filtering = "stringent",
  alpha = 0.05,
  lfc = 1
)
```

---

## Output

The pipeline generates:

### 📁 Output directory
- Organized folders with all plots

### 📊 Visualizations
- QC plots
- PCA plots
- Heatmaps
- Volcano plots
- Normalization diagnostics

### 📑 Excel Report
- `DE_Report.xlsx` containing:
  - QC summaries
  - Filtering statistics
  - Imputed and normalized data
  - Differential expression results

---

## Notes

- The pipeline requires **user input** to select the imputation method.
- Ensure metadata sample labels match LFQ column names exactly.
- Designed primarily for **protein-level analysis**.

---

## Author

Raúl Fernández Contreras

---

## License

This project is open-source. You can adapt the license as needed (e.g., MIT, GPL-3).

---
