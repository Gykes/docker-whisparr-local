# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.21 as builder

# Install build dependencies
RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    dotnet8-sdk \
    git \
    nodejs \
    npm \
    curl

# Clone and build your custom Whisparr
ARG WHISPARR_REPO="https://github.com/gykes/Whisparr.git"
ARG WHISPARR_BRANCH="develop"

WORKDIR /src
RUN \
  echo "**** clone and build whisparr ****" && \
  git clone --depth 1 --branch ${WHISPARR_BRANCH} ${WHISPARR_REPO} . && \
  echo "**** build frontend ****" && \
  npm install --legacy-peer-deps && \
  npm run build && \
  echo "**** build backend ****" && \
  dotnet publish src/Whisparr -c Release -o /app/whisparr/bin \
    --self-contained --runtime linux-musl-x64 \
    /p:PublishSingleFile=false \
    /p:PublishReadyToRun=true

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.21

# set version label
ARG BUILD_DATE
ARG VERSION
ARG APP_VERSION
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="Gykes"
LABEL org.opencontainers.image.source="https://github.com/gykes/Whisparr"
LABEL org.opencontainers.image.url="https://github.com/gykes/Whisparr"
LABEL org.opencontainers.image.description="Custom build of Whisparr - An adult movie collection manager for Usenet and BitTorrent users."
LABEL org.opencontainers.image.authors="Gykes"

# environment settings
ARG APP_BRANCH="custom"
ENV XDG_CONFIG_HOME="/config/xdg"

RUN \
  echo "**** install runtime packages ****" && \
  apk add -U --upgrade --no-cache \
    icu-libs \
    sqlite-libs

# Copy built application from builder stage
COPY --from=builder /app/whisparr/bin /app/whisparr/bin

RUN \
  echo "**** create package info ****" && \
  echo -e "UpdateMethod=docker\nBranch=${APP_BRANCH}\nPackageVersion=${VERSION}\nPackageAuthor=[gykes](https://github.com/gykes)" > /app/whisparr/package_info && \
  printf "Version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  rm -rf \
    /app/whisparr/bin/Whisparr.Update \
    /tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 6969

VOLUME /config