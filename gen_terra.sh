#!/bin/bash

if [ -a tmp ]; then rm tmp -rf; fi
mkdir tmp
cd tmp

for i in public private;
do
    echo "======== $i ========"
    cp ../cobe-$i.brain* .
    echo "Sacando frases..."
    echo "select message from $i where message not like '%http%' and date >= date_sub(now(), interval 15 minute) order by id asc" | mysql -s -uterra -pterra terra > terra-unsorted-$i.txt
    echo "Filtrando..."
    sort terra-unsorted-$i.txt | uniq > terra-$i.txt
    echo "Entrenando..."
    cobe -b cobe-$i.brain learn terra-$i.txt
    echo "Hecho."
done

mv cobe* ..
cd ..
rm tmp -rf
echo "Fin."