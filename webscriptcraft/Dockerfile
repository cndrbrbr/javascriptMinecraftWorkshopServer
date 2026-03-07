# Serve the webscriptcraft IDE (static files from openb3/) via nginx
FROM nginx:trixie

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && git clone --depth=1 https://github.com/cndrbrbr/webscriptcraft.git /tmp/ws \
    && cp -r /tmp/ws/openb3/. /usr/share/nginx/html/ \
    && rm -rf /tmp/ws \
    && apt-get purge -y git && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 80
