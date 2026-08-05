# Build-Kontext muss der Repo-Root sein (nicht dieses Verzeichnis!), da
# qwirkle_server per Pfad von ../qwirkle_net/../qwirkle_core abhängt:
#
#   docker build -f packages/qwirkle_server/Dockerfile -t qwirkle-server .
#
# So baut es auch der `deploy-server.yml`-GitHub-Actions-Workflow.

FROM dart:stable AS build

WORKDIR /app
COPY packages/qwirkle_core packages/qwirkle_core
COPY packages/qwirkle_net packages/qwirkle_net
COPY packages/qwirkle_server packages/qwirkle_server

WORKDIR /app/packages/qwirkle_server
RUN dart pub get
# `dart compile exe` erzeugt ein eigenständiges natives Binary (kein
# separates Runtime-Binary nötig, anders als `dart compile aot-snapshot`).
RUN dart compile exe bin/server.dart -o /app/qwirkle_server

# Debian-Slim statt scratch/alpine: das kompilierte Binary ist dynamisch
# gegen glibc gelinkt (offizielle Dart-Empfehlung für `dart compile exe`).
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 qwirkle

COPY --from=build /app/qwirkle_server /usr/local/bin/qwirkle_server

ENV PORT=8080
ENV DATA_DIR=/data/rooms
ENV ROOM_RETENTION_DAYS=14

RUN mkdir -p /data/rooms && chown -R qwirkle:qwirkle /data
VOLUME ["/data"]
EXPOSE 8080

USER qwirkle
ENTRYPOINT ["/usr/local/bin/qwirkle_server"]
