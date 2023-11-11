#!/bin/bash

OUTPUT="./out"

rm -rf $OUTPUT && mkdir -p $OUTPUT

cp ./index.html $OUTPUT

cp -r ./public/. $OUTPUT
find $OUTPUT -type f -name "*.puml" -o -name "*.plantuml" \
    -exec plantuml -tsvg {} \;

for FILE in ./content/*.md; do
    FILENAME=$(basename -- "$FILE" .md)
    pandoc $FILE --template=./utils/content-template.html \
        --lua-filter=./utils/header-links.lua \
        --toc \
        -o "$OUTPUT/$FILENAME.html"
    sed -i 's/<sup>\(.*\)<\/sup>/[\1]/g' "$OUTPUT/$FILENAME.html"
    sed -i ':a;N;$!ba;s/\(<a[^>]*class="footnote-back"[^>]*>[^<]*<\/a>\)/ | \1/g' "$OUTPUT/$FILENAME.html"
done
