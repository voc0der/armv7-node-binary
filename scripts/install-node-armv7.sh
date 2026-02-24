#!/usr/bin/env bash
# install-node-armv7.sh
#
# Downloads the latest Node.js ARMv7 build from the builds repo and installs it.
# Intended for use inside Dockerfiles or CI jobs building for ARMv7.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/voc0der/armv7-node-binary/main/scripts/install-node-armv7.sh | bash
#   # or with options:
#   NODE_MAJOR=24 INSTALL_DIR=/usr/local bash install-node-armv7.sh
#
# Environment vars:
#   NODE_MAJOR     - Node major version (default: 24)
#   INSTALL_DIR    - Where to install (default: /usr/local)
#   BUILDS_REPO    - GitHub repo slug (default: voc0der/armv7-node-binary)
#   GH_TOKEN       - Optional GitHub token for higher API rate limits

set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-24}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local}"
BUILDS_REPO="${BUILDS_REPO:-voc0der/armv7-node-binary}"
API_BASE="https://api.github.com/repos/${BUILDS_REPO}"

echo ">>> Fetching Node.js v${NODE_MAJOR} ARMv7 build from ${BUILDS_REPO}"

# Build curl auth header if token provided
AUTH_HEADER=""
if [ -n "${GH_TOKEN:-}" ]; then
  AUTH_HEADER="Authorization: Bearer ${GH_TOKEN}"
fi

curl_gh() {
  if [ -n "$AUTH_HEADER" ]; then
    curl -fsSL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" "$@"
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "$@"
  fi
}

# Get latest release matching our major version
RELEASES=$(curl_gh "${API_BASE}/releases?per_page=20")
RELEASE=$(echo "$RELEASES" | \
  grep -o '"tag_name": *"[^"]*"' | \
  grep "\"v${NODE_MAJOR}\." | \
  head -1 | \
  grep -o '"v[^"]*"' | \
  tr -d '"')

if [ -z "$RELEASE" ]; then
  echo "ERROR: No release found for Node.js v${NODE_MAJOR} in ${BUILDS_REPO}"
  exit 1
fi

echo ">>> Found release: ${RELEASE}"

# Get the tarball download URL
TARBALL_URL=$(curl_gh "${API_BASE}/releases/tags/${RELEASE}" | \
  grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' | \
  head -1 | \
  grep -o 'https://[^"]*')

if [ -z "$TARBALL_URL" ]; then
  echo "ERROR: Could not find tarball in release ${RELEASE}"
  exit 1
fi

echo ">>> Downloading: ${TARBALL_URL}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$TARBALL_URL" -o "${TMP}/node.tar.gz"

# Verify checksum if SHASUMS256.txt is available
SHASUMS_URL="${TARBALL_URL%/*}/SHASUMS256.txt"
if curl -fsSL "$SHASUMS_URL" -o "${TMP}/SHASUMS256.txt" 2>/dev/null; then
  echo ">>> Verifying checksum..."
  (cd "$TMP" && sha256sum -c SHASUMS256.txt --ignore-missing)
  echo ">>> Checksum OK"
else
  echo ">>> (Checksum file not available, skipping verification)"
fi

echo ">>> Installing to ${INSTALL_DIR}"
tar -xzf "${TMP}/node.tar.gz" --strip-components=1 -C "${INSTALL_DIR}"

echo ""
echo ">>> Node.js ARMv7 installed:"
ls "${INSTALL_DIR}/bin/node" && file "${INSTALL_DIR}/bin/node" || true
echo ""
echo ">>> Done! Make sure ${INSTALL_DIR}/bin is on your PATH."
