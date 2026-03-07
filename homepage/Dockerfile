FROM nginx:alpine

# envsubst is included in nginx:alpine via gettext
COPY html/ /usr/share/nginx/template/

# Entrypoint replaces ${IDE_URL}, ${UPLOAD_URL}, ${MC_ADDRESS} at container start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
