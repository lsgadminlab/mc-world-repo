# ─────────────────────────────────────────────
# Stage 1: Download PaperMC JAR
# ─────────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS builder

ARG PAPER_VERSION=1.21.11
ARG PAPER_BUILD
ARG PAPER_URL="https://fill-data.papermc.io/v1/objects/5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba/paper-1.21.11-132.jar"

WORKDIR /build
RUN apk add --no-cache curl jq

RUN set -eux; \
    echo "Downloading Paper from: ${PAPER_URL}"; \
    curl -fL --retry 5 --retry-delay 2 -o paper.jar "${PAPER_URL}"
      
# ─────────────────────────────────────────────
# Stage 2: Runtime image
# ─────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="lsgadminlab" \
      org.opencontainers.image.title="PaperMC" \
      org.opencontainers.image.version="1.21.11" \
      org.opencontainers.image.source="https://github.com/lsgadminlab/PaperMC-K8s-Resources"

ENV MC_RAM_MIN=1G \
    MC_RAM_MAX=4G \
    MC_EXTRA_OPTS=""

RUN addgroup -S minecraft && adduser -S minecraft -G minecraft

WORKDIR /server

COPY --from=builder /build/paper.jar paper.jar

RUN echo "eula=true" > eula.txt

COPY --chown=minecraft:minecraft . .

RUN chown -R minecraft:minecraft /server

USER minecraft

EXPOSE 25565

ENTRYPOINT ["sh", "-c", \
    "exec java \
        -Xms${MC_RAM_MIN} \
        -Xmx${MC_RAM_MAX} \
        -XX:+UseG1GC \
        -XX:+ParallelRefProcEnabled \
        -XX:MaxGCPauseMillis=200 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+DisableExplicitGC \
        -XX:+AlwaysPreTouch \
        -XX:G1NewSizePercent=30 \
        -XX:G1MaxNewSizePercent=40 \
        -XX:G1HeapRegionSize=8M \
        -XX:G1ReservePercent=20 \
        -XX:G1HeapWastePercent=5 \
        -XX:G1MixedGCCountTarget=4 \
        -XX:InitiatingHeapOccupancyPercent=15 \
        -XX:G1MixedGCLiveThresholdPercent=90 \
        -XX:G1RSetUpdatingPauseTimePercent=5 \
        -XX:SurvivorRatio=32 \
        -XX:+PerfDisableSharedMem \
        -XX:MaxTenuringThreshold=1 \
        ${MC_EXTRA_OPTS} \
        -jar paper.jar \
        --nogui"]
