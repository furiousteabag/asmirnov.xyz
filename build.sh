#!/bin/bash

OUTPUT="./out"

rm -rf $OUTPUT && mkdir -p $OUTPUT

cp ./index.html $OUTPUT
cp -r ./images $OUTPUT

for FILE in ./content/*.md
do
  FILENAME=$(basename -- "$FILE" .md)
  pandoc $FILE --template=./content/template.html -o "$OUTPUT/$FILENAME.html"
done
