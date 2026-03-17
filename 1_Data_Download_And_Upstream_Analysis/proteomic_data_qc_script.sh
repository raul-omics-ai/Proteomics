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

########################
# Generate QC metrics CSV
########################
QC_CSV="$OUTPUT_DIR/QC_metrics_description.csv"

echo "Generating QC metrics description table..."
cat << 'EOF' > "$QC_CSV"
Section,Metric,Description,Good Quality,Bad Quality
Experimental Design and Metadata,Experimental Design,"Tabla recoge la información sobre el diseño experimental si se ha utilizado un archivo SDRF para introducir la información en MaxQuant.",,
Experimental Design and Metadata,Parameters,"Parámetros utilizados a la hora de configurar el Software de MaxQuant. Representa la misma información que el archivo parameters.txt",,
Results Overview,Summary Table*,"Tabla con resumen descriptivo sobre el número total de espectros MS2, el número de péptidos identificados en MS2, el % de péptidos identificados en MS2, el número de péptidos identificados, el número de proteínas identificadas y el número de proteínas cuantificadas.",,
Results Overview,Heatmap*,"Figura resumen del control de calidad general de los parámetros evaluados.",,
Identification Summary,Number of Peptides identified Per Protein*,"Número de péptidos necesarios para identificar una proteína.","Pico centrado en 2–3 péptidos.","Pico centrado en 1 o distribución anómala."
Identification Summary,ProteinGroups Counts,"Proteínas identificadas por muestra (incluye Match Between Runs).","Alta proporción de identificaciones genuinas.","Muchas identificaciones transferidas."
Identification Summary,Peptide ID Count,"Igual que el anterior, pero para péptidos.","Igual que el anterior.","Igual que el anterior."
Identification Summary,Missed Cleavages Per Raw File*,"Porcentaje de cortes inespecíficos.","Alta proporción de cortes específicos (>80%).","≥20% de cortes inespecíficos."
Identification Summary,Modifications Per Raw File,"Porcentaje de modificaciones post-traduccionales.","Variable según experimento.","Variable según experimento."
Identification Summary,MS/MS Identified Per Raw File*,"Porcentaje de espectros MS/MS útiles.","10–40% aceptable, >40% óptimo.","<10% problemático."
Search Engine Scores,Search Engine Scores*,"Distribución de scores del motor de búsqueda.","Distribuciones homogéneas.","Distribuciones sesgadas."
Contaminants,Top5 Contaminants Per Raw File*,"Top 5 proteínas contaminantes.","<5% ideal.","Alto porcentaje."
Contaminants,Potential Contaminants Per File,"Porcentaje total de contaminantes.","<5–7%.",">7–10%."
Quantification Analysis,Protein Intensity Distribution*,"Distribución de intensidades de proteínas.","Homogeneidad entre muestras.","Sesgos visibles."
Quantification Analysis,LFQ Intensity Distribution*,"Distribución de intensidades LFQ.","Homogeneidad.","Sesgos."
Quantification Analysis,Peptide Intensity Distribution*,"Distribución de intensidades de péptidos.","Homogeneidad.","Sesgos."
Quantification Analysis,PCA of Raw Intensity*,"PCA de intensidades en bruto.","Separación por PCs.","Sin separación."
Quantification Analysis,PCA of LFQ Intensity*,"PCA de intensidades LFQ.","Separación biológica.","Sin separación."
MS2 and Spectral Stats,Charge-state of Per File*,"Distribución del estado de carga.","Predominio Z=2 y Z=3.","Muchos Z=1."
MS2 and Spectral Stats,MS/MS Counts Per 3D-peak*,"MS/MS necesarios por péptido.","Mayoría con un MS/MS.","0 o múltiples MS/MS."
Mass Error Trends,Delta Mass [Da]*,"Error de masa del precursor (Da).","Centrado en 0.","Desplazado o multimodal."
Mass Error Trends,Delta Mass [ppm],"Error de masa del precursor (ppm).","Centrado en 0.","Desplazado."
Mass Error Trends,Uncalibrated Mass Error,"Error previo a calibración.","Homogéneo.","Alta variabilidad."
RT Quality Control,Ids over RT*,"Aprovechamiento del gradiente LC.","Meseta estable.","Perfiles irregulares."
RT Quality Control,Peak width over RT,"Ancho de picos cromatográficos.","Uniforme.","Ruidoso."
RT Quality Control,TopN over RT,"Evolución de TopN durante el gradiente.","Constante.","Variable."
RT Quality Control,TopN,"Frecuencia de eventos TopN.","TopN alto frecuente.","Variabilidad entre muestras."
EOF

echo "QC metrics table created:"
echo "→ $QC_CSV"
echo ""
echo "All results available in: $OUTPUT_DIR"
