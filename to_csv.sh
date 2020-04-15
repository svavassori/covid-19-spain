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
# 160 lines of data + some empty/spurious lines
pdftotext $FILE_IN $TEXT_OUT
FIRST_LINE=$(awk '/Andalucía/ {print FNR; exit}' $TEXT_OUT)
LAST_LINE=$(awk '/^IA \(14 d.\): Incidencia acumulada/ {print FNR; exit}' $TEXT_OUT)
cat $TEXT_OUT | head -n $LAST_LINE | tail -n +$FIRST_LINE > $INFO

# keep first 20 lines (CCAA) and only the ones starting with a number
# delete dots from "thousands" (e.g. 3.453 -> 3453)
# substitute comas with dots   (e.g.  6,44 -> 6.44)
# remove yen symbol (¥)
# put each number on a line
cat $INFO | awk '(NR<=20) || /^[0-9]/' \
          | tr -d '¥*' \
          | sed -e 's/\([0-9]\)\./\1/g' -e 's/,/./g' -e 's/\([0-9\.]\+\) \([0-9\.]\+\)/\1\n\2/g' \
          > $CLEANED

# read all info into array for easier lookup
IFS=$'\t' read -r -a arr <<< $(cat $CLEANED | tr '\n' '\t')

# mangling to have the same order in the table
# the first 3 columns are OK (column first) while
# the sequent 4 columns are row first.
# The 4th adn 5th column misses the "total", this
# means they're 19 positions long instead of 20
# Add placeholder to align indexes
#
# ${X[@]:index:length} slice from index to index+length exclusive
#
arr=("${arr[@]:0:136}" -1 -1 "${arr[@]:136}")
new_arr=("${arr[@]:0:60}")
for column_index in {60..63}
do
	for row in {0..19}
	do
		new_arr+=(${arr[$column_index + row * 4]})
	done
done
new_arr+=("${arr[@]:140}")

# calculate the sum of the missing columns
function sum() {
	local -n array=$1
	local offset=$2
	local sum=0

	for i in {0..18}
	do
		sum=$(($sum + ${array[$offset + $i]}))
	done

	array[$offset + 19]=$sum
}
sum new_arr 60
sum new_arr 80

# write CSV file
MOD_DATE=$(pdfinfo -isodates ${FILE_IN}| awk '/ModDate/ { print $2}')
TIME=$(date --date=$MOD_DATE --iso-8601=seconds | sed 's/+.\+$//g')
DATE=$(date --date=$MOD_DATE --iso-8601)
[[ $# -eq 2 ]] && FILE_OUT="$2" || FILE_OUT="datos-ccaa-${DATE}.csv"

cat $HEADER > $FILE_OUT
LAST=","

for line in {0..19}
do
	echo -n "$TIME" >> $FILE_OUT
	for offset in {0..140..20}
	do
		echo -n ",${new_arr[$line + $offset]}" >> $FILE_OUT
	done
	echo "" >> $FILE_OUT
done

# delete temporary files
rm $TEXT_OUT $INFO $CLEANED

