#!/bin/bash
echo "Sacando frases..."
echo "select message from public where message not like '%http%'" | mysql -s -uterra -pterra terra > terra-unsorted.txt
echo "Filtrando..."
sort terra-unsorted.txt | uniq > terra.txt
rm terra-unsorted.txt
echo "Entrenando..."
mkdir tmp
cd tmp
mv ../terra.txt .
cobe learn terra.txt
mv cobe* ..
cd ..
rm tmp -r
echo "Ya está."
