# ============================================================
# Spigot container — multi-stage build
#
# Stage 1: Build the script4kids plugin from source
# Stage 2: Runtime image
#
# Spigot itself is NOT built during image build.
# The entrypoint builds it on first start (via BuildTools)
# and caches the JAR on the persistent volume.
# Set FORCE_BUILD=true to rebuild even if JAR already exists.
# ============================================================

# ── Stage 1: Build plugin ───────────────────────────────────
FROM eclipse-temurin:21-jdk-bookworm AS plugin-builder

RUN apt-get update && apt-get install -y git maven && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/cndrbrbr/script4kids.git /build
WORKDIR /build
RUN mvn clean package -DskipTests -q

# ── Stage 2: Runtime ────────────────────────────────────────
# JDK needed to run BuildTools (compiles Spigot on first start)
FROM eclipse-temurin:21-jdk-bookworm

RUN apt-get update && apt-get install -y git curl inotify-tools && rm -rf /var/lib/apt/lists/*

# Pre-download BuildTools so the container doesn't need internet at startup
RUN mkdir -p /buildtools && \
    curl -fsSL -o /buildtools/BuildTools.jar \
        https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

WORKDIR /server-base

# Plugin JAR
COPY --from=plugin-builder /build/target/jsmn-1.0-SNAPSHOT.jar plugins/

# Server config
COPY eula.txt server.properties server-icon.png whitelist.json ./

# Startup script + watch_copy utility
COPY entrypoint.sh /entrypoint.sh
COPY watch_copy.sh /watch_copy.sh
RUN chmod +x /entrypoint.sh /watch_copy.sh

WORKDIR /server

EXPOSE 25565 25580

ENTRYPOINT ["/entrypoint.sh"]
