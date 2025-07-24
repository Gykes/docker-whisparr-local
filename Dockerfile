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
    yarn \
    curl \
    bash

# Clone and build your custom Whisparr
ARG WHISPARR_REPO="https://github.com/Gykes/Whisparr.git"
ARG WHISPARR_BRANCH="develop"

WORKDIR /src
RUN \
  echo "**** clone and build whisparr ****" && \
  git clone --depth 1 --branch ${WHISPARR_BRANCH} ${WHISPARR_REPO} . && \
  echo "**** setup node version and corepack ****" && \
  npm i -g corepack && \
  corepack enable && \
  echo "**** build frontend ****" && \
  yarn install && \
  yarn build && \
  echo "**** build backend ****" && \
  dotnet clean src/Whisparr.sln -c Release && \
  dotnet msbuild -restore src/Whisparr.sln -p:Configuration=Release -p:Platform=Posix -t:PublishAllRids && \
  echo "**** copy build output ****" && \
  mkdir -p /app/whisparr/bin && \
  cp -r _output/net6.0/linux-musl-x64/* /app/whisparr/bin/

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.21

# set version label
ARG BUILD_DATE
ARG VERSION
ARG APP_VERSION
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="Gykes"
LABEL org.opencontainers.image.source="https://github.com/Gykes/Whisparr"
LABEL org.opencontainers.image.url="https://github.com/Gykes/Whisparr"
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
  echo -e "UpdateMethod=docker\nBranch=${APP_BRANCH}\nPackageVersion=${VERSION}\nPackageAuthor=[Gykes](https://github.com/Gykes)" > /app/whisparr/package_info && \
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