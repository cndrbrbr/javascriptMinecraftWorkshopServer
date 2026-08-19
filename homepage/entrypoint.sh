#!/bin/sh
set -e

# Copy template files and substitute environment variables in HTML
cp -r /usr/share/nginx/template/. /usr/share/nginx/html/

VARS='${IDE_URL} ${UPLOAD_URL} ${MC_ADDRESS}'

# index.html and the Blockly-Kurs pages link to IDE_URL; kurs-js has no
# template variables and is served as copied above.
# Absolute-path globs: the working directory here isn't the template dir,
# so a relative "kurs/lektionen/*.html" glob would never match.
for f in /usr/share/nginx/template/index.html \
         /usr/share/nginx/template/kurs/index.html \
         /usr/share/nginx/template/kurs/lektionen/*.html; do
  rel="${f#/usr/share/nginx/template/}"
  envsubst "$VARS" < "$f" > "/usr/share/nginx/html/$rel"
done

exec nginx -g 'daemon off;'
