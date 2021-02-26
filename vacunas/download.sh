#!/bin/bash

FILE_PDF="Informe_GIV_comunicacion_$(date +%+4Y%m%d).pdf"
OPTS="--no-verbose --timestamping --directory-prefix=informes"
URL="https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov/documentos/"
wget ${OPTS} "${URL}${FILE_PDF}"

if [ $? -eq 8 ]
then
    # server returned an error
    exit 0
fi

# extract PDF modifcation date
DATE=$(date +%F --date=$(pdfinfo -isodates informes/${FILE_PDF} | awk '/ModDate:/ { print $2}'))

# extract data only for CC.AA. list, should be 7 columns:
#
# CC.AA. name |
# delivered Pfizer | delivered Moderna | delivered AstraZeneca |
# total delivered | administered | vaccinated
#
# change separator from space to ',' to help identify columns
# removes dot (thousands) from numbers
# change ',' to '.' from percent
# fixes CC.AA. names
java -jar tika-app-1.25.jar --text "informes/${FILE_PDF}" \
    | perl -p0e 's/Castilla La \n\nMancha\n/Castilla La Mancha /g' \
    | grep --file=pattern_ccaa \
    | sed -e 's/ \?\*//g' \
          -e 's/\([a-z0-9]\) \([0-9]\)/\1,\2/g' \
          -e 's/\([0-9]\)\.\([0-9]\)/\1\2/g' \
          -e 's/\([0-9]\),\([0-9][0-9]\?%\) /\1.\2,/' \
          -e 's/Baleares/Islas Baleares/g' \
          -e 's/Leon/León/g' \
          -e 's/Castilla La Mancha/Castilla-La Mancha/g' \
          -e 's/C. Valenciana/Comunidad Valenciana/g' \
    | awk -F ',' '{ print $1","$2","$3","$4","$6","$8}' \
    | python3 to_json.py ${DATE} - data/

# merge daily with cumulative ones
DATA_FILES=("administered" "delivered" "vaccinated")
for file in ${DATA_FILES[@]}
do
    jq --null-input '[ inputs ] | flatten' "data/regions_${file}.json" "data/${DATE}_${file}.json" | sponge "data/regions_${file}.json"
    tail --lines=+2 "data/${DATE}_${file}.csv" >> "data/regions_${file}.csv"
done

# create summary files for Spain
for file in ${DATA_FILES[@]}
do
    jq '[ group_by(.date, .supplier)
        | .[]
        | { date: .[0] | .date,
            iso_code: "ES",
            nuts1: "ES",
            name: "España",
            supplier: .[0] | .supplier, '"\
            ""${file} : ( map(.${file})"' | reduce .[] as $sum (0; . + $sum) ) } ]' \
            "data/regions_${file}.json" \
        > "data/state_${file}.json"
    cat "data/regions_${file}.csv" \
    | q --skip-header --output-header --delimiter=, \
        "SELECT date, 'ES' AS iso_code, 'ES' AS nuts, 'España' AS name, supplier, sum(${file}) AS ${file} \
         FROM - GROUP BY date, supplier" \
    > "data/state_${file}.csv"
done

# removes temporary files
rm "data/${DATE}_"*
