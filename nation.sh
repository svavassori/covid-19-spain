#! /bin/bash

FILES="csv/*[0-9].csv"
ESP="csv/datos-españa.csv"
CCAA="csv/datos-ccaa.csv"

cp header $ESP
cp header $CCAA

grep --no-filename "Total," $FILES | sed 's/Total/España/g' >> $ESP
grep --no-filename --invert-match "Total" $FILES >> $CCAA
