#! /bin/bash

if [ $# -eq 0 ]; then
	echo "Usage: inputfile [ outputfile ]"
	exit -1
fi

FILE_IN="$1"
TEXT_OUT="text.out"
INFO="info"
CLEANED="cleaned"
HEADER="header"

# Find first line and extract all table data
# 140 lines of data + some empty/spurious lines
pdftotext $FILE_IN $TEXT_OUT
FIRST_LINE=$(awk '/Andalucía/ {print FNR; exit}' $TEXT_OUT)
cat $TEXT_OUT | tail -n +$FIRST_LINE | head -n 160 > $INFO

# keep first 20 lines (CCAA) and only the ones starting with a number
# delete dots from "thousands" (e.g. 3.453 -> 3453)
# substitute comas with dots (e.g.  6,44 -> 6.44)
cat $INFO | awk '(NR<=20) || /^[0-9]/' | sed -e 's/\([0-9]\)\./\1/g' -e 's/,/./g' > $CLEANED

# read all info into array for easier lookup
IFS=$'\t' read -r -a arr <<< $(cat $CLEANED | tr '\n' '\t')
RECOVERED=$(grep "hasta el momento se han registrado" $TEXT_OUT | sed -e 's/\.//g' -e 's/.\+y \([0-9]\+\) curado.*/\1/g')

# write CSV file
MOD_DATE=$(pdfinfo -isodates ${FILE_IN}| awk '/ModDate/ { print $2}')
TIME=$(date --date=$MOD_DATE --rfc-3339=seconds | sed 's/+.\+$//g')
DATE=$(date --date=$MOD_DATE --iso-8601)
[[ $# -eq 2 ]] && FILE_OUT="$2" || FILE_OUT="datos-ccaa-${DATE}.csv"

cat $HEADER > $FILE_OUT
LAST=","

for line in {0..19}
do
	echo -n "$TIME" >> $FILE_OUT
	for offset in {0..120..20}
	do
		echo -n ",${arr[$line + $offset]}" >> $FILE_OUT
	done
	if [ $line -eq 19 ]; then
		LAST=",$RECOVERED"
	fi
	echo $LAST >> $FILE_OUT
done

# delete temporary files
rm $TEXT_OUT $INFO $CLEANED
