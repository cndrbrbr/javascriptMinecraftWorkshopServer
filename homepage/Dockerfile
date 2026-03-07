FROM nginx:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY html/ /usr/share/nginx/template/

# Entrypoint replaces ${IDE_URL}, ${UPLOAD_URL}, ${MC_ADDRESS} at container start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
