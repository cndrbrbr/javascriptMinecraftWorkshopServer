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

# ── Stage 1a: Build script4kids plugin ─────────────────────
FROM debian:trixie-slim AS plugin-builder

RUN apt-get update && apt-get install -y openjdk-21-jdk git maven && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/cndrbrbr/script4kids.git /build
WORKDIR /build
RUN mvn clean package -DskipTests -q

# ── Stage 1b: Build geomaptools plugin ──────────────────────
FROM debian:trixie-slim AS geomaptools-builder

RUN apt-get update && apt-get install -y openjdk-21-jdk git maven && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/cndrbrbr/geomaptools.git /build
WORKDIR /build
# pom.xml doesn't declare the SpigotMC repo — inject it via settings.xml
RUN mkdir -p /root/.m2 && printf '<settings><profiles><profile><id>spigot</id><repositories><repository><id>spigot-snapshots</id><url>https://hub.spigotmc.org/nexus/content/repositories/snapshots/</url></repository></repositories></profile></profiles><activeProfiles><activeProfile>spigot</activeProfile></activeProfiles></settings>' > /root/.m2/settings.xml
RUN mvn clean package -DskipTests -q

# ── Stage 2: Runtime ────────────────────────────────────────
# GraalVM JDK is used so the jsmn plugin's shaded Truffle/Polyglot runtime can
# use JVMCI for optimised JS compilation. Standard OpenJDK lacks JVMCI, which
# means Truffle falls back to slow interpretation. The jsmn plugin (script4kids)
# shades org.graalvm.polyglot and the Truffle runtime into its JAR via the
# maven-shade-plugin, so no additional classpath setup is needed at runtime.
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y git curl tar gzip && rm -rf /var/lib/apt/lists/*

# Install GraalVM Community JDK 21 (provides the GraalVM Polyglot/Truffle runtime)
ARG GRAALVM_VERSION=21.0.2
RUN curl -fsSL \
        "https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-${GRAALVM_VERSION}/graalvm-community-jdk-${GRAALVM_VERSION}_linux-x64_bin.tar.gz" \
    | tar -xzC /opt/ && \
    mv "$(find /opt -maxdepth 1 -name 'graalvm-community-openjdk-*' -type d)" /opt/graalvm
ENV JAVA_HOME=/opt/graalvm
ENV PATH=$JAVA_HOME/bin:$PATH

# Pre-download BuildTools so the container doesn't need internet at startup
RUN mkdir -p /buildtools && \
    curl -fsSL -o /buildtools/BuildTools.jar \
        https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

WORKDIR /server-base

# Plugin JARs
COPY --from=plugin-builder /build/target/jsmn-1.0-SNAPSHOT.jar plugins/
COPY --from=geomaptools-builder /build/target/geomaptools.jar plugins/

# Prometheus Exporter plugin
RUN curl -fsSL -o plugins/PrometheusExporter.jar \
        https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v3.1.2/minecraft-prometheus-exporter-3.1.2.jar
COPY prometheus-exporter-config.yml plugins/PrometheusExporter/config.yml

# Server config
COPY eula.txt server.properties server-icon.png whitelist.json ./

# Startup script + watch_copy utility
COPY entrypoint.sh /entrypoint.sh
COPY watch_copy.sh /watch_copy.sh
RUN chmod +x /entrypoint.sh /watch_copy.sh

WORKDIR /server

EXPOSE 25565 25580 9940

ENTRYPOINT ["/entrypoint.sh"]
