#!/bin/bash

# download updated files
URLS=(
	"https://cnecovid.isciii.es/covid19/resources/datos_ccaas.csv"
	"https://cnecovid.isciii.es/covid19/resources/datos_provincias.csv"
	"https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov/documentos/Datos_Casos_COVID19.csv"
)

OPTS="--no-verbose --timestamping --directory-prefix=csv"

for url in "${URLS[@]}"
do
	wget ${OPTS} ${url}
done

# convert from ISO-8859-14 to UTF-8
DATA_FILE="csv/Datos_Casos_COVID19.csv"
if file --brief $DATA_FILE | grep --quiet "ISO-8859"; then
	iconv --from-code=ISO-8859-1 --to-code=UTF-8 $DATA_FILE | sponge $DATA_FILE
fi

CURRENT=$(find pdf/ -name "*.pdf" | sed 's/.\+_\([0-9]\+\)_.\+/\1/g' | sort --numeric-sort --unique | tail -n 1)
NEXT=$((CURRENT+1))
wget --no-verbose --directory-prefix=pdf/ "https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov-China/documentos/Actualizacion_${NEXT}_COVID-19.pdf"


# replace CCAA codes with full name
FILE="csv/datos_ccaas.csv"
FILE_ESP="csv/casos-españa.csv"
cat $FILE | sed --regexp-extended \
                -e 's/AN,/Andalucía,/g' \
                -e 's/AR,/Aragón,/g' \
                -e 's/AS,/Asturias,/g' \
                -e 's/IB,/Baleares,/g' \
                -e 's/CN,/Canarias,/g' \
                -e 's/CB,/Cantabria,/g' \
                -e 's/CM,/Castilla La Mancha,/g' \
                -e 's/CL,/Castilla y León,/g' \
                -e 's/CT,/Cataluña,/g' \
                -e 's/CE,/Ceuta,/g' \
                -e 's/VC,/C. Valenciana,/g' \
                -e 's/EX,/Extremadura,/g' \
                -e 's/GA,/Galicia,/g' \
                -e 's/MD,/Madrid,/g' \
                -e 's/ML,/Melilla,/g' \
                -e 's/MC,/Murcia,/g' \
                -e 's/NC,/Navarra,/g' \
                -e 's/PV,/País Vasco,/g' \
                -e 's/RI,/La Rioja,/g' \
          > $FILE_ESP

# create 'cases' file
QUERY_CASOS="SELECT 'España' AS España, fecha, SUM(num_casos) AS casos, "
QUERY_CASOS+="SUM(num_casos_prueba_pcr) AS pcr, "
QUERY_CASOS+="SUM(num_casos_prueba_test_ac) AS testAc, "
QUERY_CASOS+="SUM(num_casos_prueba_otras) AS otras, "
QUERY_CASOS+="SUM(num_casos_prueba_desconocida) AS desconocida "
QUERY_CASOS+="FROM - "
QUERY_CASOS+="GROUP BY fecha "
cat $FILE_ESP | q --skip-header --delimiter=, "$QUERY_CASOS" >> $FILE_ESP

# sort by date without header and then add the new header
tail --lines=+2 $FILE_ESP | sort --key=2 --field-separator=, --output $FILE_ESP
sed -i '1 i\localidad,fecha,casos,pcr,testAc,otras,desconocida' $FILE_ESP


# This file is supposed-to-be the one they use to create
# the PDF, but some data like current (not new daily)
# hospitalized or ICU are missing while present in the PDF.
#
# * it removes the first 7 lines full of comments
# * changes ; with ,
# * reformat date from dd-mm-yyyy to yyyy-mm-dd
# * calculate totals for Spain
FILE_PDF_ESP="csv/datos-pdf-españa.csv"
tail -n +7 "${DATA_FILE}" | \
      sed --regexp-extended \
          -e 's/;/,/g' \
          -e 's/([0-9]+)-([0-9]+)-([0-9]+)/\3-\2-\1/g' \
          -e 's/ES-AN,/Andalucía,/g' \
          -e 's/ES-AR,/Aragón,/g' \
          -e 's/ES-AS,/Asturias,/g' \
          -e 's/ES-IB,/Baleares,/g' \
          -e 's/ES-CN,/Canarias,/g' \
          -e 's/ES-CB,/Cantabria,/g' \
          -e 's/ES-CM,/Castilla La Mancha,/g' \
          -e 's/ES-CL,/Castilla y León,/g' \
          -e 's/ES-CT,/Cataluña,/g' \
          -e 's/ES-CE,/Ceuta,/g' \
          -e 's/ES-VC,/C. Valenciana,/g' \
          -e 's/ES-EX,/Extremadura,/g' \
          -e 's/ES-GA,/Galicia,/g' \
          -e 's/ES-MD,/Madrid,/g' \
          -e 's/ES-ML,/Melilla,/g' \
          -e 's/ES-MC,/Murcia,/g' \
          -e 's/ES-NC,/Navarra,/g' \
          -e 's/ES-PV,/País Vasco,/g' \
          -e 's/ES-RI,/La Rioja,/g' \
      > $FILE_PDF_ESP

QUERY_PDF="SELECT 'España' AS España, Fecha, SUM(Casos_Diagnosticados) AS casos, "
QUERY_PDF+="SUM(Hospitalizados) AS hospitalizados, SUM(UCI) AS uci, "
QUERY_PDF+="SUM(Fallecidos) AS fallecidos "
QUERY_PDF+="FROM - "
QUERY_PDF+="GROUP BY Fecha ORDER BY Fecha"

cat $FILE_PDF_ESP | q --delimiter=, --skip-header "$QUERY_PDF" >> $FILE_PDF_ESP

# sort by date without header and then add the new header
tail --lines=+2 $FILE_PDF_ESP | sort --key=2 --field-separator=, --output $FILE_PDF_ESP
sed -i '1 i\localidad,fecha,casos,hospitalizados,uci,fallecidos' $FILE_PDF_ESP
