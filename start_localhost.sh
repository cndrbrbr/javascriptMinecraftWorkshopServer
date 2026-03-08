#!/bin/bash
set -e
cd "$(dirname "$0")"
sudo docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
