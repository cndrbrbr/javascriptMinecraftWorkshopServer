# Serve webscriptcraft (static files from openb3/) via nginx --
# the IDE at /ide.html; / redirects there. Courses (kurs/, kurs-js/) live in
# the javascriptMinecraftWorkshopServer homepage container, not here.
FROM nginx:trixie

# Cache-bust: this URL's body changes whenever webscriptcraft gets a new commit
# on main, so plain `docker compose build` (no --no-cache needed) re-clones
# instead of silently reusing a stale layer from an earlier build.
ADD https://api.github.com/repos/cndrbrbr/webscriptcraft/commits/main /tmp/webscriptcraft-head.json

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && git clone --depth=1 https://github.com/cndrbrbr/webscriptcraft.git /tmp/ws \
    && cp -r /tmp/ws/openb3/. /usr/share/nginx/html/ \
    && rm -rf /tmp/ws /tmp/webscriptcraft-head.json \
    && apt-get purge -y git && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 80
