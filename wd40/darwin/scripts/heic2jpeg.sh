#!/bin/bash
# wd40: heic2jpeg - convert .heic files under a directory to .jpg (macOS sips)

pushd "$1" > /dev/null

find "$1" -type f \( -iname '*.heic' \) -print0 \
| while IFS= read -r -d '' f; do
    sips -s format jpeg "$f" --out "${f%.*}.jpg"
  done

echo "Conversion complete!"
popd > /dev/null
