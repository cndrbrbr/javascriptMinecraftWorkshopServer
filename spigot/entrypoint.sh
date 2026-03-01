#!/bin/bash
set -e

# ── Initialise the data volume on first run ─────────────────
# Always update the plugin JAR so rebuilds take effect.
mkdir -p /server/plugins
cp /server-base/plugins/*.jar /server/plugins/

# Copy server files only if they don't already exist
# (preserves world data, config changes, and whitelist across restarts)
for f in paper.jar eula.txt server.properties; do
    [ -f "/server/$f" ] || cp "/server-base/$f" "/server/$f"
done

# ── Start the server ────────────────────────────────────────
cd /server

exec java \
    -Xmx2G \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+EnableJVMCI \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens=java.base/java.lang.ref=ALL-UNNAMED \
    --add-opens=java.base/java.nio=ALL-UNNAMED \
    --add-opens=java.base/java.util=ALL-UNNAMED \
    --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
    -Dpolyglot.engine.WarnInterpreterOnly=false \
    -jar paper.jar nogui
