
# 📌 Automated Proteomics Workflow (LFQ – MaxQuant / DIA-NN / quantMS)

This repository contains a set of scripts designed to automate the complete workflow for *label-free quantification (LFQ)* proteomics data analysis—from raw file download to full statistical analysis using **DEP** in R.

The goal is to provide a reproducible, modular, and scalable pipeline for proteomics analysis.

---

## ✅ Repository Structure

```
.
├── 1_raw_data_download/
│   └── download_proteomic_rawfiles.sh
├── 2_quality_control/
│   └── proteomic_data_qc_script.sh
├── 3_downstream_analysis/
│   └── auto_proteomic_analysis.R 
├── src/
│   ├── proteomics_env_r4.1.3_11022026.yaml
│   └── Guia_MaxQuant_Windows.txt
└── README.md
```

---

## ✅ File Descriptions

### **1. Raw Data Download**
📁 `1_raw_data_download/download_proteomic_rawfiles.sh`  
Bash script that:

- Automatically downloads **.raw** files from PRIDE projects (FTP/HTTPS).  
- Generates an accession list (`AccList.txt`).  
- Skips files already present in the directory.  
- Saves a detailed log file (`download.log`).  
- Automatically downloads the **cRAP** contaminants database.

Usage:
```bash
./download_proteomic_rawfiles.sh -u <PRIDE_URL> -o <OUTPUT_DIR>
```

---

### **2. Quality Control (MultiQC)**
📁 `2_quality_control/proteomic_data_qc_script.sh`  
QC pipeline based on **MultiQC**, compatible with:

- MaxQuant  
- DIA-NN  
- quantMS

Generates:
- MultiQC HTML report  
- CSV file with QC metrics

Usage:
```bash
./proteomic_data_qc_script.sh -s maxquant -i <input_dir> -o <output_dir>
```

---

### **3. Downstream Analysis**
📁 `3_downstream_analysis/auto_proteomic_analysis.R`  
R script that automatically performs a full DEP-based workflow, including:

- Data loading (MS2, peptides, proteinGroups).  
- Initial QC.  
- Contaminant and decoy filtering.  
- Missing data filtering.  
- Imputation (with interactive selection).  
- Normalization (VSN).  
- Sample-level QC.  
- Differential abundance analysis.  
- Export of results to `DE_Report.xlsx` plus multiple figures.

Usage:
```r
auto_proteomic_analysis(
  ms2_file_path = "evidence.txt",
  peptide_file_path = "peptides.txt",
  proteinGroup_file_path = "proteinGroups.txt",
  metadata = metadata_df,
  where_to_save = "results/",
  title = "My_Analysis"
)
```

---

### **Recommended Conda Environment**
📄 `3_downstream_analysis/proteomics_env_r4.1.3_11022026.yaml`

Create the environment:
```bash
conda env create -f proteomics_env_r4.1.3_11022026.yaml
conda activate proteomics_env
```

---

### **Documentation**
📁 `src/Guia_MaxQuant_Windows.txt`

Practical guide for running MaxQuant on Windows.

---

## ✅ How to Run the Full Pipeline

### **1. Download .raw files**
```bash
cd 1_raw_data_download
./download_proteomic_rawfiles.sh -u <PRIDE_URL> -o raw_data/
```

### **2. MultiQC quality control**
```bash
cd 2_quality_control
./proteomic_data_qc_script.sh -s maxquant -i <MQ_output_dir> -o qc_report/
```

### **3. Downstream analysis in R**
```r
source("3_downstream_analysis/auto_proteomic_analysis.R")
```

---

## ✅ License

Add your preferred license here (MIT, GPL-3, etc.).

---
