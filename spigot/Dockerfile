# ============================================================
# Spigot container
#
# Plugins are downloaded as release JARs built for MC_VERSION
# (see the ARGs below — bump a version there to update a plugin).
#
# Spigot itself is NOT built during image build.
# The entrypoint builds it on first start (via BuildTools)
# and caches the JAR on the persistent volume.
# Set FORCE_BUILD=true to rebuild even if JAR already exists.
# ============================================================
FROM debian:trixie-slim

# Minecraft/Spigot version. Plugin release JARs below are picked to match it.
ARG MC_VERSION=26.3

# Plugin versions (GitHub release tags).
# script4kids (jsmn), cavecompass and geomaptools publish one release per
# Minecraft version, tagged v<version>-mc<MC_VERSION>.
ARG JSMN_VERSION=1.1.0
ARG CAVECOMPASS_VERSION=0.10.1
ARG GEOMAPTOOLS_VERSION=4.37
ARG PROMETHEUS_EXPORTER_VERSION=3.1.2

RUN apt-get update && apt-get install -y git curl tar gzip && rm -rf /var/lib/apt/lists/*

# GraalVM Community JDK 25. Spigot 26.x needs Java 25, and the jsmn plugin
# (script4kids) runs JavaScript via GraalVM Polyglot/Truffle: on a GraalVM JDK
# Truffle can use JVMCI for optimised JS compilation instead of slow
# interpretation. The plugin shades the Polyglot/Truffle runtime into its JAR,
# so no additional classpath setup is needed at runtime.
ARG GRAALVM_VERSION=25.0.2
RUN curl -fsSL \
        "https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-${GRAALVM_VERSION}/graalvm-community-jdk-${GRAALVM_VERSION}_linux-x64_bin.tar.gz" \
    | tar -xzC /opt/ && \
    mv "$(find /opt -maxdepth 1 -name 'graalvm-community-openjdk-*' -type d)" /opt/graalvm
ENV JAVA_HOME=/opt/graalvm
ENV PATH=$JAVA_HOME/bin:$PATH
ENV SPIGOT_VERSION=${MC_VERSION}

# Pre-download BuildTools so the container doesn't need internet at startup
RUN mkdir -p /buildtools && \
    curl -fsSL -o /buildtools/BuildTools.jar \
        https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

WORKDIR /server-base

# Plugin JARs
RUN mkdir -p plugins && cd plugins && \
    curl -fsSL -o "jsmn-${JSMN_VERSION}-mc${MC_VERSION}.jar" \
        "https://github.com/cndrbrbr/script4kids/releases/download/v${JSMN_VERSION}-mc${MC_VERSION}/jsmn-${JSMN_VERSION}-mc${MC_VERSION}.jar" && \
    curl -fsSL -o "CaveCompass-${CAVECOMPASS_VERSION}-mc${MC_VERSION}.jar" \
        "https://github.com/cndrbrbr/cavecompass/releases/download/v${CAVECOMPASS_VERSION}-mc${MC_VERSION}/CaveCompass-${CAVECOMPASS_VERSION}-mc${MC_VERSION}.jar" && \
    curl -fsSL -o "geomaptools-${GEOMAPTOOLS_VERSION}-mc${MC_VERSION}.jar" \
        "https://github.com/cndrbrbr/geomaptools/releases/download/v${GEOMAPTOOLS_VERSION}-mc${MC_VERSION}/geomaptools-${GEOMAPTOOLS_VERSION}-mc${MC_VERSION}.jar" && \
    curl -fsSL -o PrometheusExporter.jar \
        "https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v${PROMETHEUS_EXPORTER_VERSION}/minecraft-prometheus-exporter-${PROMETHEUS_EXPORTER_VERSION}.jar"
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
