# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/rust/.devcontainer/base.Dockerfile

# [Choice] Debian OS version (use bookworm on local arm64/Apple Silicon): buster, bullseye, bookworm

ARG VARIANT=bookworm
FROM mcr.microsoft.com/vscode/devcontainers/rust:${VARIANT}

# Install additional packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends protobuf-compiler libprotobuf-dev libclang-dev libzstd-dev

RUN apt install -y gh libgmp3-dev software-properties-common

# To allow independent workflow of the container, the rust-toolchain is explicitely given.
RUN echo "1.80.0" > rust_toolchain_version
# Make sure to sync the nightly version with the scripts in ./scripts
RUN echo "nightly-2024-08-28" > nightly_rust_toolchain_version

# Install cargo-binstall
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

RUN rustup toolchain install $(cat rust_toolchain_version) && \
    rustup default $(cat rust_toolchain_version) && \
    rustup component add clippy && \
    rustup component add rustfmt

RUN rustup toolchain install $(cat nightly_rust_toolchain_version) && \
	rustup component add rustfmt clippy --toolchain $(cat nightly_rust_toolchain_version)

RUN rustup target add x86_64-pc-windows-msvc && \
    rustup target add wasm32-unknown-unknown

RUN cargo binstall cargo-get cargo-nextest cargo-release --secure -y

RUN chown -R root:root /usr/local/cargo
RUN chmod -R 700 /usr/local/cargo
