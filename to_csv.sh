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

# Find first line and extract all table data (100 lines + 4 empty lines)
pdftotext $FILE_IN $TEXT_OUT
FIRST_LINE=$(awk '/Andalucía/ {print FNR}' $TEXT_OUT)
cat $TEXT_OUT | tail -n +$FIRST_LINE | head -n 104 > $INFO

# delete dots in "thousands" (e.g. 3.453 -> 3453)
# changes comas with dots    (e.g.  6,44 -> 6.44)
sed -e '/^$/d' -e 's/\([0-9]\)\./\1/g' -e 's/,/./g' $INFO > $CLEANED

# read all info into array for easier lookup
IFS=$'\t' read -r -a arr <<< $(cat $CLEANED | tr '\n' '\t')

# write CSV file
MOD_DATE=$(pdfinfo -isodates ${FILE_IN}| awk '/ModDate/ { print $2}')
TIME=$(date --date=$MOD_DATE --rfc-3339=seconds | sed 's/+.\+$//g')
DATE=$(date --date=$MOD_DATE --iso-8601)
[[ $# -eq 2 ]] && FILE_OUT="$2" || FILE_OUT="datos-ccaa-${DATE}.csv"

cat $HEADER > $FILE_OUT

for line in {0..19}
do
	echo -n "$TIME" >> $FILE_OUT
	for offset in {0..80..20}
	do
		echo -n ",${arr[$line + $offset]}" >> $FILE_OUT
	done
	echo "" >> $FILE_OUT
done

# delete temporary files
rm $TEXT_OUT $INFO $CLEANED
