#! /bin/bash

if [ $# -eq 0 ]; then
	echo "Usage: inputfile [ outputfile ]"
	exit -1
fi

FILE_IN="$1"
TEXT_OUT="text.out"
TABLE_1="table1"
TABLE_2="table2"
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
# * single space at end of line
# * leading spaces before alpha character
# * dots from "thousands" (e.g. 3.453 -> 3453)
#   substitute number with a "+" in front of them (e.g. +1234) with a space
#   substitute comas with dots   (e.g.  6,44 -> 6.44)
# * two extra space after "ESPAÑA"
# * newlines before spaces and a number
cat $TEXT_OUT | tr -d '*¥' \
              | sed -e 's/ $//g' \
                    -e '/^$/d' \
                    -e 's/^ \+\([[:alpha:]]\)/\1/g' \
                    -e 's/\([0-9]\)\./\1/g' \
                    -e 's/^+[0-9]\+//g' \
                    -e 's/,/./g' \
                    -e 's/ESPAÑA  /ESPAÑA/g' \
              | sed --null-data \
                    -e 's/\([0-9]\)\n\+\( \+[0-9]\)/\1\2/g' \
                    -e 's/\([ 0-9]\)\n\+\([0-9]\)/\1 \2/g' \
              > $INFO


# Save Table1 and Table2 and
extract_table $INFO $TABLE_1 $(awk '/^Tabla 1/ { print FNR}' $INFO)
extract_table $INFO $TABLE_2 $(awk '/^Tabla 2/ { print FNR}' $INFO)

# write CSV file
MOD_DATE=$(pdfinfo -isodates ${FILE_IN}| awk '/ModDate/ { print $2}')
TIME=$(date --date=$MOD_DATE --iso-8601=seconds | sed 's/+.\+$//g')
DATE=$(date --date=$MOD_DATE --iso-8601)
[[ $# -eq 2 ]] && FILE_OUT="$2" || FILE_OUT="datos-ccaa-${DATE}.csv"

cat $HEADER > $FILE_OUT
paste --delimiters ',' $TABLE_1 $TABLE_2 \
        | cut --delimiter=, --fields=1-8,10- \
        | awk --assign time="$TIME" --field-separator ',' \
          '{hospTot+=$9; hospNew+=$10; uciTot+=$11; uciNew+=$12} \
          NR != 20 { print time","$0} \
          END { print time","$1","$2","$3","$4","$5","$6","$7","$8","hospTot","hospNew","uciTot","uciNew","$13","$14","$15","$16}' \
        >> $FILE_OUT

# delete temporary files
rm $TEXT_OUT $TABLE_1 $TABLE_2 $INFO
