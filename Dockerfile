# Build stage: build-base
FROM erlang:22-slim as build-base

# Install build dependencies
RUN set -xe \
  && apt-get update \
  && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    cmake \
    libssl-dev \
    libsodium-dev \
    libsnappy-dev \
    liblz4-dev \
    libdbus-1-dev \
  && echo "Done"

# Install Rust toolchain
RUN set -xe \
  && curl https://sh.rustup.rs -sSf | \
    sh -s -- \
      --default-host x86_64-unknown-linux-gnu \
      --default-toolchain stable \
      --profile default \
      -y \
  && echo "Done"

RUN set -xe \
  && apt-get update \
  && apt-get install -y \
    automake \
    autoconf \
    libtool \
    pkg-config \
    flex \
    bison \
    libgmp-dev \
  && echo "Done"

# Build stage: build-dummy
FROM build-base as build-dummy

# Copy our dependency config only
COPY ./rebar* /validator/

# Set workdir
WORKDIR /validator

# Compile dependencies to make things more repeatable
RUN set -xe \
  && . $HOME/.cargo/env \
  && ./rebar3 as docker_val do compile \
  && echo "Done"

# Build stage: build-main
FROM build-dummy as build-main

# Copy project files
COPY . /validator

# Set workdir
WORKDIR /validator

# Build release
RUN ./rebar3 as docker_val do release

# TODO: Switch to a simple debian:buster-slim.
# We shouldn't need all of erlang's runtime for a release

# Build stage: runtime
FROM erlang:22-slim as runtime

# Install the runtime dependencies
RUN set -xe \
  && apt-get update \
  && apt-get install -y \
    openssl \
    libsodium23 \
    libsnappy1v5 \
    lz4 \
    iproute2 \
    libncurses6 \
    libgmp10 \
    libdbus-1-3 \
  && echo "Done"

# Install the released application
COPY --from=build-main /validator/_build/docker_val/rel/miner /validator/

# Set workdir
WORKDIR /validator

# Command
CMD /validator/bin/miner foreground