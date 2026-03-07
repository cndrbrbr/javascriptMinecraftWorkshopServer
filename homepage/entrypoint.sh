#!/bin/sh
set -e

# Copy template files and substitute environment variables in HTML
cp -r /usr/share/nginx/template/. /usr/share/nginx/html/
envsubst '${IDE_URL} ${UPLOAD_URL} ${MC_ADDRESS}' \
  < /usr/share/nginx/template/index.html \
  > /usr/share/nginx/html/index.html

exec nginx -g 'daemon off;'
