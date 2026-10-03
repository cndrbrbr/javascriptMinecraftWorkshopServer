#!/bin/bash
set -e

# Set by the Dockerfile (ARG MC_VERSION); fallback for running outside the image
SPIGOT_VERSION="${SPIGOT_VERSION:-26.3}"
SPIGOT_JAR="/server/spigot-${SPIGOT_VERSION}.jar"

# ── Build Spigot if not on volume ────────────────────────────
if [ ! -f "$SPIGOT_JAR" ] || [ "${FORCE_BUILD:-false}" = "true" ]; then
    echo "==> Building Spigot ${SPIGOT_VERSION} via BuildTools (this takes a few minutes)..."
    BUILD_DIR=$(mktemp -d)
    cd "$BUILD_DIR"
    java -jar /buildtools/BuildTools.jar --rev "${SPIGOT_VERSION}" --compile SPIGOT
    cp "${BUILD_DIR}/spigot-${SPIGOT_VERSION}.jar" "$SPIGOT_JAR"
    rm -rf "$BUILD_DIR"
fi

# ── Volume directory structure ────────────────────────────────
mkdir -p /server/data/cfg /server/data/plugins /server/data/worlds

# ── Plugin: always update so image rebuilds take effect ──────
# Remove older versions of the plugins this image manages first: their JAR
# names contain the version, so a new JAR would otherwise load next to the old
# one (e.g. jsmn-1.0-SNAPSHOT.jar from before the 26.3 upgrade).
rm -f /server/data/plugins/jsmn-*.jar /server/data/plugins/CaveCompass-*.jar /server/data/plugins/geomaptools*.jar
cp /server-base/plugins/*.jar /server/data/plugins/
mkdir -p /server/data/plugins/PrometheusExporter
cp /server-base/plugins/PrometheusExporter/config.yml /server/data/plugins/PrometheusExporter/config.yml

# ── Config: copy to volume on first run only ─────────────────
[ -f /server/eula.txt ]            || echo "eula=true" > /server/eula.txt
[ -f /server/server-icon.png ]     || cp /server-base/server-icon.png /server/server-icon.png
[ -f /server/data/cfg/server.properties ] || cp /server-base/server.properties /server/data/cfg/server.properties
[ -f /server/whitelist.json ]      || cp /server-base/whitelist.json /server/whitelist.json

# ── watch_copy: push image config changes to volume at runtime
/watch_copy.sh /server-base/server.properties /server/data/cfg/server.properties &

# ── Start server with crash-restart loop ─────────────────────
cd /server

while true; do
    java \
        -Xms${MC_MEM_MIN:-512M} \
        -Xmx${MC_MEM_MAX:-2G} \
        --add-opens=java.base/java.lang=ALL-UNNAMED \
        --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
        --add-opens=java.base/java.lang.ref=ALL-UNNAMED \
        --add-opens=java.base/java.nio=ALL-UNNAMED \
        --add-opens=java.base/java.util=ALL-UNNAMED \
        -jar "$SPIGOT_JAR" \
        --config "./data/cfg/server.properties" \
        --bukkit-settings "./data/cfg/bukkit.yml" \
        --spigot-settings "./data/cfg/spigot.yml" \
        --commands-settings "./data/cfg/commands.yml" \
        --plugins "./data/plugins" \
        --world-dir "./data/worlds" \
        --level-name "${MC_LEVELNAME:-world}" \
        --max-players "${MC_MAXPLAYERS:-30}" \
        --port "${MC_PORT:-25565}" \
        nogui

    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "==> Server normal gestoppt – kein Neustart."
        break
    fi

    echo "==> Server-Crash (Code $EXIT_CODE) – Neustart in 5 Sekunden..."
    sleep 5
done
