#!/bin/bash

OUTPUT="./out"

rm -rf $OUTPUT && mkdir -p $OUTPUT

cp ./index.html $OUTPUT

cp -r ./images $OUTPUT
find $OUTPUT/images -type f -name "*.puml" -o -name "*.plantuml" \
    -exec plantuml -tsvg {} \;

for FILE in ./content/*.md; do
    FILENAME=$(basename -- "$FILE" .md)
    pandoc $FILE --template=./utils/content-template.html \
        --lua-filter=./utils/header-links.lua \
        --toc --toc-depth=3 \
        -o "$OUTPUT/$FILENAME.html"
done
