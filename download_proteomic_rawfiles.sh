#!/bin/bash

set -euo pipefail

usage() {
    echo "Uso: $0 -u <URL_PRIDE> -o <DIR_SALIDA>"
    echo
    echo "Ejemplo:"
    echo "  $0 -u https://ftp.pride.ebi.ac.uk/pride/data/archive/2024/10/PXD052549/ -o ./raw_data"
    exit 1
}

URL=""
OUTDIR=""

while getopts ":u:o:h" opt; do
    case $opt in
        u) URL="$OPTARG" ;;
        o) OUTDIR="$OPTARG" ;;
        h) usage ;;
        \?) echo "Opción inválida: -$OPTARG" >&2; usage ;;
        :)  echo "La opción -$OPTARG requiere un argumento." >&2; usage ;;
    esac
done

if [[ -z "$URL" || -z "$OUTDIR" ]]; then
    usage
fi

mkdir -p "$OUTDIR"

ACC_LIST="$OUTDIR/AccList.txt"
LOGFILE="$OUTDIR/download.log"

echo "[INFO] Explorando repositorio PRIDE"
echo "       $URL"
echo "[INFO] Generando lista de archivos .raw → $ACC_LIST"

wget -qO- "$URL" \
| grep -o 'href="[^"]*\.raw"' \
| sed 's/href="//;s/"//' > "$ACC_LIST"

N=$(wc -l < "$ACC_LIST")

if [[ "$N" -eq 0 ]]; then
    echo "[ERROR] No se encontraron archivos .raw en la URL proporcionada."
    exit 2
fi

echo "[INFO] Encontrados $N archivos .raw"
echo "[INFO] Descargando en: $OUTDIR"
echo "[INFO] Log detallado: $LOGFILE"
echo

i=1
while read -r f; do
    TARGET="$OUTDIR/$f"

    if [[ -f "$TARGET" ]]; then
        echo "[$i/$N] YA EXISTE: $f"
    else
        echo "[$i/$N] DESCARGANDO: $f"
        if wget -c \
                --progress=bar:force:noscroll \
                -P "$OUTDIR" "${URL}${f}" >> "$LOGFILE" 2>&1; then
            echo "[$i/$N] OK: $f"
        else
            echo "[$i/$N] ERROR: $f (ver log)"
        fi
    fi

    ((i++))
done < "$ACC_LIST"

echo
echo "[INFO] Proceso finalizado."

