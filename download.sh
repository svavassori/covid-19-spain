#!/bin/bash

# download updated files
URLS=(
	"https://cnecovid.isciii.es/covid19/resources/datos_ccaas.csv"
	"https://cnecovid.isciii.es/covid19/resources/datos_provincias.csv"
	"https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov-China/documentos/Fallecidos_COVID19.xlsx"
)

OPTS="--no-verbose --timestamping --directory-prefix=csv"

for url in "${URLS[@]}"
do
	wget ${OPTS} ${url}
done

CURRENT=$(find pdf/ -name "*.pdf" | sed 's/.\+_\([0-9]\+\)_.\+/\1/g' | sort --numeric-sort --unique | tail -n 1)
NEXT=$((CURRENT+1))
wget --no-verbose --directory-prefix=pdf/ "https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov-China/documentos/Actualizacion_${NEXT}_COVID-19.pdf"


# replace CCAA codes with full name
FILE="csv/datos_ccaas.csv"
FILE_ESP="csv/casos-españa.csv"
FILE_DEATHS="csv/Fallecidos_COVID19.csv"
DEATHS="csv/Fallecidos_COVID19.xlsx"
TMP="tmp"
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

# create cumulative deaths file
# and changes the date format
libreoffice --headless --convert-to "csv:Text - txt - csv (StarCalc):44,,76,1" --outdir csv $DEATHS
head --lines=-1 $FILE_DEATHS | awk --field-separator ',' \
    '{if (NR==1) { print $0 }
      else {
        { printf "%s",$1 }
        for (i=2; i<=NF; i++) {
          ccaa[i]+=$i;
          { printf ",%d", ccaa[i] }
        }
        print ""
      }
    }' \
    | sed --regexp-extended \
          -e 's| / CCAA||g' \
          -e 's|^([0-9]+)/([0-9]+)/([0-9]+)|\3-\2-\1|g' \
    > $TMP
mv $TMP $FILE_DEATHS