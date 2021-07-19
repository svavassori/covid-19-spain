#!/bin/bash

# download updated files
FILE_CAP_ASISTENCIAL="Datos_Capacidad_Asistencial_Historico_$(date +%d%m%Y).csv"
FILE_CAP_HOSP="csv/Datos_Capacidad_Asistencial_Historico.csv"

URLS=(
      "https://cnecovid.isciii.es/covid19/resources/casos_diagnostico_ccaa.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_diagnostico_provincia.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_diag_ccaadecl.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_hosp_uci_def_sexo_edad_provres.csv"
      "https://cnecovid.isciii.es/covid19/resources/metadata_ccaa_prov_res.pdf"
      "https://cnecovid.isciii.es/covid19/resources/metadata_ccaadecl_prov_edad_sexo.pdf"
      "https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov/documentos/${FILE_CAP_ASISTENCIAL}"
)

OPTS="--no-verbose --timestamping --directory-prefix=csv"

for url in "${URLS[@]}"
do
	wget ${OPTS} ${url}
done

# convert "Datos_Capacidad_Asistencial_Historico" from 8859-15 to UTF-8, keeps original timestamp
iconv --output="${FILE_CAP_HOSP}" --from-code=ISO_8859-15 --to-code=UTF-8 "csv/${FILE_CAP_ASISTENCIAL}"
touch --reference="csv/${FILE_CAP_ASISTENCIAL}" "${FILE_CAP_HOSP}"
rm "csv/${FILE_CAP_ASISTENCIAL}"

# create state-level aggregated data
QUERY_HOSP="SELECT Fecha As fecha, CCAA AS ccaa, Unidad AS unidad, "
QUERY_HOSP+="SUM(TOTAL_CAMAS) AS total_camas, "
QUERY_HOSP+="SUM(OCUPADAS_COVID19) AS ocupadas_covid19, "
QUERY_HOSP+="SUM(OCUPADAS_NO_COVID19) AS ocupadas_no_covid19, "
QUERY_HOSP+="SUM(INGRESOS_COVID19) AS ingresos_covid19, "
QUERY_HOSP+="SUM(ALTAS_24h_COVID19) AS altas_24h_covid19 "
QUERY_HOSP+="FROM - "
QUERY_HOSP+="GROUP BY Fecha, CCAA, UNIDAD ORDER BY Fecha"

# rewrite date
# group by date, ccaa and care category
cat "${FILE_CAP_HOSP}" \
    | sed 's|^\([0-9]\+\)/\([0-9]\+\)/\([0-9]\+\)|\3-\2-\1|g' \
    | sed --file=lowercase.sed \
    | q --skip-header --delimiter=';' --output-delimiter=, --output-header "${QUERY_HOSP}" \
    > "csv/datos_capacidad_asistencial-españa.csv"



CURRENT=$(find pdf/ -name "*.pdf" | sed 's/.\+_\([0-9]\+\)_.\+/\1/g' | sort --numeric-sort --unique | tail -n 1)
NEXT=$((CURRENT+1))
wget --no-verbose --directory-prefix=pdf/ "https://www.mscbs.gob.es/profesionales/saludPublica/ccayes/alertasActual/nCov-China/documentos/Actualizacion_${NEXT}_COVID-19.pdf"


# replace province codes with CC.AA. full name and calculate aggregated values
# removes the 'NC' lines since they are not assigned to any CC.AA.
FILE="csv/casos_hosp_uci_def_sexo_edad_provres.csv"
FILE_ESP="csv/datos-españa.csv"

QUERY_PROV="SELECT ccaa, fecha, SUM(num_casos) AS num_casos, "
QUERY_PROV+="SUM(num_hosp) AS num_hosp, "
QUERY_PROV+="SUM(num_uci) AS num_uci, "
QUERY_PROV+="SUM(num_def) AS num_def "
QUERY_PROV+="FROM - "
QUERY_PROV+="GROUP BY ccaa, fecha "
cat $FILE | grep -v "^NC" \
          | sed --file=province.sed \
          | q --skip-header --output-header --delimiter=, "$QUERY_PROV" \
          > $FILE_ESP

# calculate aggregated values for Spain
QUERY_CASOS="SELECT 'España' AS España, fecha, SUM(num_casos) AS casos, "
QUERY_CASOS+="SUM(num_hosp) AS hospitalizados, "
QUERY_CASOS+="SUM(num_uci) AS uci, "
QUERY_CASOS+="SUM(num_def) AS fallecidos "
QUERY_CASOS+="FROM - "
QUERY_CASOS+="GROUP BY fecha "
cat $FILE_ESP | q --skip-header --delimiter=, "$QUERY_CASOS" >> $FILE_ESP

# sort by date without header and then add the new header
tail --lines=+2 $FILE_ESP | sort --key=2 --field-separator=, --output $FILE_ESP
sed -i '1 i\localidad,fecha,casos,hospitalizados,uci,fallecidos' $FILE_ESP
