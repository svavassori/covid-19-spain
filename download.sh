# !/bin/bash

YESTERDAY=$(date --date=yesterday +%F)
FILE_CCAA="datos-ccaa.csv"
FILE_ESP="datos-españa.csv"
FILE="serie_historica_acumulados.csv"
URL="https://covid19.isciii.es/resources/${FILE}"
OPTS="--no-verbose --output-document=${FILE}"

cd "csv/"
wget $OPTS $URL

# delete carriage return
# delete 'NOTA' lines at end
# sums "PCR+" and "TestAc+" if present, otherwise uses "casos" field
# rearrange date field to be first
# removes trailing comma
# format date as YYYY-MM-DD
# replace CCAA codes with full name
cat $FILE | tr -d '\r' \
          | awk '/^[A-Z][A-Z],[0-9]/ || NR <=1 { print $0}' \
          | awk 'BEGIN { FS=OFS="," } \
                 { if (NR <= 1) { print $0, "TotalPositivos" } \
                   else { \
                       if ($4) { totalPositive=$4+$5 } \
                       else { totalPositive=$3 } \
                       print $0, totalPositive
                   } \
                 }' \
          | awk 'BEGIN { FS=OFS="," } { print $2, $1, $3, $4, $5, $6, $7, $8, $9, $10, $11 }' \
          | sed --regexp-extended \
                -e 's/,$//g' \
                -e 's|([0-9]+)/([0-9]+)/([0-9]+)|\3-\2-\1|g' \
                -e 's/-([0-9])-/-0\1-/g' \
                -e 's/-([0-9]),/-0\1,/g' \
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
                -e 's/2020-04-28,Galicia,9466/2020-04-28,Galicia,/g' \
          > $FILE_CCAA

# create country file
QUERY=" SELECT FECHA, 'España' AS CCAA, SUM(CASOS) AS CASOS, "
QUERY+='SUM("PCR+") AS "PCR+", SUM("TestAc+") AS "TestAc+",'
QUERY+="SUM(Hospitalizados) AS Hospitalizados, SUM(UCI) AS UCI,"
QUERY+="SUM(Fallecidos) AS Fallecidos, SUM(Recuperados) AS Recuperados,"
QUERY+="SUM(TotalPositivos) AS TotalPositivos "
QUERY+="FROM - "
QUERY+="GROUP BY FECHA ORDER BY FECHA"

cat $FILE_CCAA | q --skip-header --output-header --delimiter=, "$QUERY" \
               | sed 's/\.0//g' \
               > $FILE_ESP
