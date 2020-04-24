#! /bin/bash

if [ $# -eq 0 ]; then
	echo "Usage: inputfile [ outputfile ]"
	exit -1
fi

FILE_IN="$1"
TEXT_OUT="text.out"
TABLE_1="table1"
TABLE_2="table2"
TABLE_34="table34"
INFO="info"
HEADER="header"

function extract_table() {

	local FILE_IN=$1
	local FILE_OUT=$2
	local STARTING_FROM=$3
	local FIRST_LINE=$(tail -n +$STARTING_FROM $FILE_IN | awk '/Andalucía/ {print FNR; exit}')
	local LAST_LINE=$(tail -n +$STARTING_FROM $FILE_IN | awk '/ESPAÑA/ {print FNR; exit}')

	cat $FILE_IN | tail -n +$STARTING_FROM \
                 | head -n $LAST_LINE \
                 | tail -n +$FIRST_LINE \
                 | tr ' ' ',' \
                 | sed 's/,\([[:alpha:]]\)/ \1/g' \
                 > $FILE_OUT
}

# Extract text from PDF
java -jar tika-app-1.24.jar --text $1 > $TEXT_OUT

# Removes:
# * star and Yen symbol
# * empty lines
# * single space at end of line and preceded by a number
# * leading spaces before alpha character
# * dots from "thousands" (e.g. 3.453 -> 3453)
# * number with a "+" in front of them (e.g. +1234)
#   substitute comas with dots   (e.g.  6,44 -> 6.44)
# * two extra space after "ESPAÑA"
# * newlines before spaces and a number
cat $TEXT_OUT | tr -d '*¥' \
              | sed -e 's/\([0-9]\) $/\1/g' \
                    -e '/^$/d' \
                    -e 's/^ \+\([[:alpha:]]\)/\1/g' \
                    -e 's/\([0-9]\)\./\1/g' \
                    -e 's/^+[0-9]\+//g' \
                    -e 's/,/./g' \
                    -e 's/ESPAÑA    /ESPAÑA/g' \
              | sed --null-data \
                    -e 's/\n \n\([0-9]\)/  \1/g' \
                    -e 's/\n\( \+[0-9]\)/\1/g' \
              > $INFO
                  #   -e 's/\([ 0-9]\)\n\+\([0-9]\)/\1 \2/g' \

# Save Table1 and Table2 and
extract_table $INFO $TABLE_1 $(awk '/^Tabla 1 / { print FNR}' $INFO)
extract_table $INFO $TABLE_2 $(awk '/^Tabla 2 / { print FNR}' $INFO)
extract_table $INFO $TABLE_34 $(awk '/^Tabla 4 / { print FNR}' $INFO)

# Sum missing column in table2
cat $TABLE_2 | awk 'BEGIN {FS=OFS=","} {hospTot+=$2; hospNew+=$3; uciTot+=$4; uciNew+=$5} \
                    NR != 20 { print $0} \
                    END { print $1, hospTot, hospNew, uciTot, uciNew, $6, $7, $8, $9}' \
             > tmp
mv tmp $TABLE_2

# write CSV file
MOD_DATE=$(pdfinfo -isodates ${FILE_IN}| awk '/ModDate/ { print $2}')
TIME=$(date --date=$MOD_DATE --iso-8601=seconds | sed 's/+.\+$//g')
DATE=$(date --date=$MOD_DATE --iso-8601)
[[ $# -eq 2 ]] && FILE_OUT="$2" || FILE_OUT="datos-ccaa-${DATE}.csv"

cat $HEADER > $FILE_OUT
paste --delimiters ',' $TABLE_1 $TABLE_2 $TABLE_34 \
    | cut --delimiter=, --fields=1-3,5,9-16,18,19,21 \
    | awk --assign time="$TIME" 'BEGIN { FS=OFS="," } \
      { print time, $1, $15, $2, $13, $4, $14, $15, $5, $6, $7, $8, $9, $10, $11, $12 }' \
    >> $FILE_OUT

# delete temporary files
rm $TEXT_OUT $TABLE_1 $TABLE_2 $TABLE_34 $INFO
