#!/bin/bash

#############################################
# Nombre: proteomic_data_qc_script.sh
# Descripción:
#   Script para automatizar el control de calidad
#   de datos de proteómica obtenidos con MaxQuant
#   utilizando MultiQC y el plugin de MaxQuant.
#
# Uso:
#   qc_maxquant.sh -i <input_dir> -o <output_dir>
#
# Opciones:
#   -i    Directorio con archivos TXT de MaxQuant
#   -o    Directorio de salida para el reporte MultiQC
#   -h    Mostrar esta ayuda
#
#############################################

# Función de ayuda
usage() {
    echo "Uso: $0 -i <input_dir> -o <output_dir>"
    echo
    echo "Opciones:"
    echo "  -i    Directorio con archivos TXT de MaxQuant"
    echo "  -o    Directorio de salida para MultiQC"
    echo "  -h    Mostrar esta ayuda"
    echo
    exit 1
}

# Variables
INPUT_DIR=""
OUTPUT_DIR=""

# Parseo de opciones
while getopts ":i:o:h" opt; do
    case ${opt} in
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
            echo "❌ Opción inválida: -$OPTARG" >&2
            usage
            ;;
        : )
            echo "❌ La opción -$OPTARG requiere un argumento." >&2
            usage
            ;;
    esac
done

# Comprobación de argumentos obligatorios
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "❌ Error: faltan argumentos obligatorios."
    usage
fi

# Comprobación de directorios
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "❌ Error: el directorio de entrada no existe: $INPUT_DIR"
    exit 1
fi

# Crear directorio de salida si no existe
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "📁 El directorio de salida no existe. Creándolo..."
    mkdir -p "$OUTPUT_DIR"
fi

# Mensaje de inicio
echo "🚀 Iniciando control de calidad con MultiQC"
echo "📂 Entrada : $INPUT_DIR"
echo "📊 Salida  : $OUTPUT_DIR"
echo

# Ejecución de MultiQC
multiqc --maxquant_plugin "$INPUT_DIR" -o "$OUTPUT_DIR"

# Comprobación del estado de salida
if [[ $? -eq 0 ]]; then
    echo
    echo "✅ Análisis de control de calidad completado con éxito."
    echo "📄 Reporte disponible en: $OUTPUT_DIR"
else
    echo
    echo "❌ Error durante la ejecución de MultiQC."
    exit 1
fi

