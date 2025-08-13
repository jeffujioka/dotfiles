#!/bin/sh

set -e

VERSION="0.18.0"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Normalize ARCH name
case "$ARCH" in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

TARBALL_URL="https://github.com/asdf-vm/asdf/releases/download/v${VERSION}/asdf-v${VERSION}-${OS}-${ARCH}.tar.gz"

# Download and extract the tarball to $HOME/.local/bin
echo "Installing asdf version $VERSION..."
echo "Downloading $TARBALL_URL..."
curl -L -o "/tmp/asdf.tar.gz" "$TARBALL_URL"
# extract to $HOME/.local/bin
echo "Extracting '/tmp/asdf.tar.gz' to '$HOME/.local/bin/'..."
mkdir -p "$HOME/.local/bin"
tar -xzf "/tmp/asdf.tar.gz" -C "$HOME/.local/bin"
rm "/tmp/asdf.tar.gz"

set +e
