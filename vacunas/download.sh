#!/bin/bash

FILE_PDF="Informe_GIV_comunicacion_$(date +%+4Y%m%d).pdf"
FILE_ODS="Informe_Comunicacion_$(date +%+4Y%m%d).ods"
OPTS="--no-verbose --timestamping --directory-prefix=informes"
URL="https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov/documentos/"
wget ${OPTS} "${URL}${FILE_PDF}"
wget ${OPTS} "${URL}${FILE_ODS}"

if [ $? -eq 8 ]
then
    # server returned an error
    exit 0
fi

# extract PDF modifcation date
DATE=$(date +%F --date=$(pdfinfo -isodates informes/${FILE_PDF} | awk '/ModDate:/ { print $2}'))

# convert from ods to csv, using:
# ; as field separator (59),
# " as text separator (34) and
# UTF-8 as enconding (76)
libreoffice --convert-to csv:"Text - txt - csv (StarCalc)":59,34,76 "informes/${FILE_ODS}"

# extract data only for CC.AA. list, should be 8 columns:
#
# CC.AA. name |
# delivered Pfizer | delivered Moderna | delivered AstraZeneca | delivered Janssen
# total delivered | administered | vaccinated
#
# fixes CC.AA. names
# fixes spaces before separator
# removes dot (thousands) from numbers
# change ',' to '.' from percent
FILE_CSV="${FILE_ODS%.ods}.csv"
cat "${FILE_CSV}" \
    | grep --file=pattern_ccaa \
    | sed -e 's/Baleares/Islas Baleares/g' \
          -e 's/Leon/León/g' \
          -e 's/Castilla \(- \)\?La Mancha/Castilla-La Mancha/g' \
          -e 's/C. Valenciana/Comunidad Valenciana/g' \
          -e 's/ \?\*//g' \
          -e 's/ ;/;/g' \
          -e 's/\.//g' \
          -e 's/\([0-9]\),\([0-9][0-9]\?%\) /\1.\2,/' \
    | awk -F ';' '{ print $1","$2","$3","$4","$5","$7","$9","$10","$11}' \
    | python3 to_json.py ${DATE} - data/ \
    && rm "${FILE_CSV}"

# append daily to cumulative ones
DATA_FILES=("administered" "delivered" "one_dose" "vaccinated" "additional_dose")
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
