#!/bin/bash


URL="https://cnecovid.isciii.es/covid19/resources"
OPTS="--no-verbose --output-document="
FILES=("agregados.csv" "datos_ccaas.csv" "datos_provincias.csv")

for file in "${FILES[@]}"
do
	wget $OPTS${file} "${URL}/${file}"
done

CURRENT=$(find pdf/ -name "*.pdf" | sed 's/.\+_\([0-9]\+\)_.\+/\1/g' | sort --numeric-sort --unique | tail -n 1)
NEXT=$((CURRENT+1))
wget --no-verbose --directory-prefix=pdf/ "https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov-China/documentos/Actualizacion_${NEXT}_COVID-19.pdf"
