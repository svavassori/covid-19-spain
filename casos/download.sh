#!/bin/bash

# download updated files
BASE_URL="https://www.sanidad.gob.es/areas/alertasEmergenciasSanitarias/alertasActuales/nCov"

LINKS_PDFS=$(wget --no-verbose --output-document=- "${BASE_URL}/situacionActual.htm" | grep --only-matching "documentos/[a-zA-Z0-9_-]\+\.pdf" | uniq)
EVALUACION_RIESGO=$(wget --no-verbose --output-document=- "${BASE_URL}/variantes.htm" | grep --only-matching "documentos/[a-zA-Z0-9_-]\+\.pdf" | head -n 1)

OPTS="--no-verbose --timestamping --directory-prefix="

wget ${OPTS}documentos/casos "${BASE_URL}"/$(echo "${LINKS_PDFS}" | grep "Actualizacion_[0-9]\+")
wget ${OPTS}documentos/variantes "${BASE_URL}"/$(echo "${LINKS_PDFS}" | grep Actualizacion_variantes)
wget ${OPTS}documentos/indicadores-de-seguimiento "${BASE_URL}"/$(echo "${LINKS_PDFS}" | grep informe_covid_es_publico)
wget ${OPTS}documentos/pruebas-laboratorio "${BASE_URL}"/$(echo "${LINKS_PDFS}" | grep pruebas_diagnosticas)
wget ${OPTS}documentos/evaluación-rápida-riesgo "${BASE_URL}/${EVALUACION_RIESGO}"

FILE_CAP_ASISTENCIAL="Datos_Capacidad_Asistencial_Historico_$(date +%d%m%Y).csv"
FILE_CAP_HOSP="Datos_Capacidad_Asistencial_Historico.csv"
FILE_TEST_DATE="Datos_Pruebas_Realizadas_Historico_$(date +%d%m%Y).csv"
FILE_TEST="Datos_Pruebas_Realizadas_Historico.csv"

URLS=(
      "https://cnecovid.isciii.es/covid19/resources/casos_tecnica_ccaa.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_tecnica_provincia.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_diag_ccaadecl.csv"
      "https://cnecovid.isciii.es/covid19/resources/casos_hosp_uci_def_sexo_edad_provres.csv"
      "https://cnecovid.isciii.es/covid19/resources/metadata_tecnica_ccaa_prov_res.pdf"
      "https://cnecovid.isciii.es/covid19/resources/metadata_diag_ccaa_decl_prov_edad_sexo.pdf"
      "https://cnecovid.isciii.es/covid19/resources/hosp_uci_def_sexo_edad_provres_todas_edades.csv"
      "${BASE_URL}/documentos/${FILE_CAP_ASISTENCIAL}"
      "${BASE_URL}/documentos/${FILE_TEST_DATE}"
)

for url in "${URLS[@]}"
do
	wget ${OPTS}csv "${url}"
done

# convert "Datos_Capacidad_Asistencial_Historico.csv"
# and "Datos_Pruebas_Realizadas_Historico.csv"
# from 8859-15 to UTF-8, keeps original timestamp
iconv --output="csv/${FILE_CAP_HOSP}" --from-code=ISO_8859-15 --to-code=UTF-8 "csv/${FILE_CAP_ASISTENCIAL}"
iconv --output="csv/${FILE_TEST}" --from-code=ISO_8859-15 --to-code=UTF-8 "csv/${FILE_TEST_DATE}"
touch --reference="csv/${FILE_CAP_ASISTENCIAL}" "csv/${FILE_CAP_HOSP}"
touch --reference="csv/${FILE_TEST_DATE}" "csv/${FILE_TEST}"
rm "csv/${FILE_CAP_ASISTENCIAL}" "csv/${FILE_TEST_DATE}"

# create state-level aggregated data for hospital capacity
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
cat "csv/${FILE_CAP_HOSP}" \
    | sed 's|^\([0-9]\+\)/\([0-9]\+\)/\([0-9]\+\)|\3-\2-\1|g' \
    | sed --file=lowercase.sed \
    | q --skip-header --delimiter=';' --output-delimiter=, --output-header "${QUERY_HOSP}" \
    > "csv/datos_capacidad_asistencial-españa.csv"

# create state-level aggregated data for diagnostic tests
QUERY_TEST="SELECT FECHA_PRUEBA AS fecha, CCAA AS ccaa, "
QUERY_TEST+="SUM(N_ANT_POSITIVOS) AS num_antigenos_positivos, "
QUERY_TEST+="SUM(N_ANT) AS num_antigenos, "
QUERY_TEST+="SUM(N_PCR_POSITIVOS) AS num_pcr_positivos, "
QUERY_TEST+="SUM(N_PCR) AS num_pcr "
QUERY_TEST+="FROM - "
QUERY_TEST+="GROUP BY FECHA_PRUEBA, CCAA "
QUERY_TEST+="ORDER BY FECHA_PRUEBA"


# reformat date (e.g. from 02JAN2021 to 2021-01-02)
# change province name with their ccaa
# group by date, ccaa
cat "csv/${FILE_TEST}" \
    | sed 's/;\([0-9]\+\)\([A-Z]\+\)\([0-9]\+\);/;\3-\2-\1;/g' \
    | sed --file months.sed \
          --file province_fullname.sed \
    | q --skip-header --delimiter=';' --output-delimiter=, --output-header "${QUERY_TEST}" \
    > "csv/datos_pruebas_realizadas-españa.csv"

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
