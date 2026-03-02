#!/bin/bash

# Config
THUMB_WIDTH=400
OUTPUT_HTML="gallery.html"
THUMB_DIR="thumbs"
FULL_DIR="suuri"

mkdir -p "$THUMB_DIR"
mkdir -p "$FULL_DIR"

ei_counter=1
tmpfile=$(mktemp)

safe_name() {
    echo "$1" | tr ' ' '-' | tr -cd '[:alnum:]-_.'
}

for img in *.jpg; do
    datetime=$(exiftool -d "%d-%m-%Y_%H-%M-%S" -DateTimeOriginal -s3 "$img")
    lens=$(exiftool -LensModel -s3 "$img")
    aperture=$(exiftool -FNumber -s3 "$img")
    shutter=$(exiftool -ShutterSpeed -s3 "$img")
    iso=$(exiftool -ISO -s3 "$img")

    if [ -z "$datetime" ]; then
        newname=$(printf "ei_dataa_%03d.jpg" $ei_counter)
        datetime_sort="0000-00-00_00-00-00"
        ((ei_counter++))
    else
        [ -z "$lens" ] && lens="tuntematon"
        [ -z "$aperture" ] && aperture="tuntematon"
        [ -z "$shutter" ] && shutter="tuntematon"
        [ -z "$iso" ] && iso="tuntematon"

        lens=$(safe_name "$lens")
        [ "$aperture" != "tuntematon" ] && aperture="f$aperture"
        [ "$shutter" != "tuntematon" ] && shutter=$(echo "$shutter" | tr '/' '-')
        [ "$iso" != "tuntematon" ] && iso="ISO$iso"

        newname="${datetime}_${lens}_${aperture}_${shutter}_${iso}.jpg"
        datetime_sort=$(echo "$datetime" | sed 's/_/:/')
    fi

    mv -n "$img" "$newname"
    mv -n "$newname" "$FULL_DIR/$newname"
    convert "$FULL_DIR/$newname" -resize ${THUMB_WIDTH}x "$THUMB_DIR/$newname"

    read width height <<< $(identify -format "%w %h" "$FULL_DIR/$newname")
    if [ "$width" -ge "$height" ]; then
        orientation="H"
    else
        orientation="V"
    fi

    echo "${datetime_sort}|${orientation}|${newname}" >> "$tmpfile"
done

sorted=$(sort -r "$tmpfile")

# Generate HTML
cat <<EOF > $OUTPUT_HTML
<!DOCTYPE html>
<html lang="fi">
<head>
<meta charset="UTF-8">
<title>Valokuvagalleria - Linuxluola</title>
<link rel="icon" href="favicon.ico" type="image/x-icon">
<link rel="stylesheet" href="tyyli.css">
</head>
<body>

<h1>Valokuvagalleria</h1>
<p>Tämä on automaattisesti luotu galleria, jossa thumbnailit linkittävät suurempiin kuviin.</p>

<h2>Vaakakuvat</h2>
<div class="gallery">
EOF

# Horizontal
echo "$sorted" | while IFS="|" read dt ori fname; do
    if [ "$ori" = "H" ]; then
        echo "<div class=\"gallery-item\">
<a target=\"_blank\" href=\"$FULL_DIR/$fname\">
<img src=\"$THUMB_DIR/$fname\" alt=\"$fname\">
</a>
<div class=\"desc\">$fname</div>
</div>" >> $OUTPUT_HTML
    fi
done

# Vertical
echo "</div>
<h2>Pystykuvat</h2>
<div class=\"gallery\">" >> $OUTPUT_HTML

echo "$sorted" | while IFS="|" read dt ori fname; do
    if [ "$ori" = "V" ]; then
        echo "<div class=\"gallery-item\">
<a target=\"_blank\" href=\"$FULL_DIR/$fname\">
<img src=\"$THUMB_DIR/$fname\" alt=\"$fname\">
</a>
<div class=\"desc\">$fname</div>
</div>" >> $OUTPUT_HTML
    fi
done

# Finish HTML
echo "</div>
</body>
</html>" >> $OUTPUT_HTML

rm "$tmpfile"

echo "Galleria luotu: $OUTPUT_HTML"
echo "Thumbnailit: $THUMB_DIR/"
echo "Koko-kuvat: $FULL_DIR/"
