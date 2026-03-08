#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./start_production.sh <domain>"
  echo "Example: ./start_production.sh meckminecraft.de"
  exit 1
fi

cd "$(dirname "$0")"

DOMAIN="$1"
SERVER_DOMAIN="$DOMAIN" \
  IDE_URL="https://javascript.$DOMAIN" \
  UPLOAD_URL="https://upload.$DOMAIN" \
  MC_ADDRESS="$DOMAIN" \
  docker compose --profile production up -d --build
