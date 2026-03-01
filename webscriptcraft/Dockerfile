# Serve the webscriptcraft IDE (static files from openb3/) via nginx
FROM nginx:alpine

RUN apk add --no-cache git && \
    git clone --depth=1 https://github.com/cndrbrbr/webscriptcraft.git /tmp/ws && \
    cp -r /tmp/ws/openb3/. /usr/share/nginx/html/ && \
    rm -rf /tmp/ws && \
    apk del git

EXPOSE 80
