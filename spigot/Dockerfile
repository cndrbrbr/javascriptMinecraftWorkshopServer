# ============================================================
# Spigot container — multi-stage build
#
# Stage 1: Build the script4kids plugin from source
# Stage 2: Download PaperMC
# Stage 3: Runtime image
# ============================================================

# ── Stage 1: Build plugin ───────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS plugin-builder

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/cndrbrbr/script4kids.git /build
WORKDIR /build
RUN mvn clean package -DskipTests -q

# ── Stage 2: Download PaperMC ───────────────────────────────
FROM eclipse-temurin:21-jre-jammy AS paper-downloader

ARG MINECRAFT_VERSION=1.21.1

RUN apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/* && \
    BUILD=$(curl -fsSL "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" \
        | jq -r '.builds[-1].build') && \
    curl -fsSL -o /paper.jar \
        "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${BUILD}/downloads/paper-${MINECRAFT_VERSION}-${BUILD}.jar"

# ── Stage 3: Runtime ────────────────────────────────────────
FROM eclipse-temurin:21-jre-jammy

WORKDIR /server-base

# Server JAR
COPY --from=paper-downloader /paper.jar ./paper.jar

# Plugin JAR
COPY --from=plugin-builder /build/target/jsmn-1.0-SNAPSHOT.jar plugins/

# Server config
COPY eula.txt server.properties ./

# Startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /server

EXPOSE 25565 25580

ENTRYPOINT ["/entrypoint.sh"]
