#!/bin/bash
set -euo pipefail

echo "Installing git-delta..."

# Temporary directory for downloading
TMP_DIR=$(mktemp -d -t delta-install-XXXXXXXXXX)

# Cleanup function
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
}

# Trap for cleanup on exit or interruption
trap cleanup EXIT INT TERM

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="amd64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="arm64"
        ;;
    armv7l)
        ARCH_SUFFIX="armhf"
        ;;
    *)
        echo "Error: Unsupported architecture $ARCH" >&2
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH (using $ARCH_SUFFIX)"

# Get latest release info from GitHub API
echo "Fetching latest git-delta release information..."
RELEASE_URL="https://api.github.com/repos/dandavison/delta/releases/latest"

if ! RELEASE_INFO=$(curl -s "$RELEASE_URL"); then
    echo "Error: Failed to fetch release information" >&2
    exit 1
fi

# Extract download URL for the appropriate .deb file
DEB_URL=$(echo "$RELEASE_INFO" | grep -o "https://github\.com[^\"]*${ARCH_SUFFIX}\.deb" | head -1)

if [ -z "$DEB_URL" ]; then
    echo "Error: Could not find compatible .deb file for architecture $ARCH_SUFFIX" >&2
    echo "Available assets:"
    echo "$RELEASE_INFO" | grep -o "https://github\.com[^\"]*\.deb" || echo "No .deb files found"
    exit 1
fi

DEB_FILE=$(basename "$DEB_URL")
echo "Found compatible package: $DEB_FILE"
echo "Download URL: $DEB_URL"

# Download the .deb file
echo "Downloading $DEB_FILE..."
if ! curl -L -o "$TMP_DIR/$DEB_FILE" "$DEB_URL"; then
    echo "Error: Failed to download $DEB_FILE" >&2
    exit 1
fi

# Verify the download
if [ ! -f "$TMP_DIR/$DEB_FILE" ]; then
    echo "Error: Downloaded file not found" >&2
    exit 1
fi

FILE_SIZE=$(stat -c%s "$TMP_DIR/$DEB_FILE")
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "Error: Downloaded file is too small ($FILE_SIZE bytes), likely corrupted" >&2
    exit 1
fi

echo "Downloaded $DEB_FILE ($FILE_SIZE bytes)"

# Install the .deb package
echo "Installing git-delta..."
if ! dpkg -i "$TMP_DIR/$DEB_FILE"; then
    echo "Error: Failed to install git-delta" >&2
    exit 1
fi

# Verify installation
if command -v delta >/dev/null 2>&1; then
    DELTA_VERSION=$(delta --version)
    echo "Successfully installed: $DELTA_VERSION"
else
    echo "Error: delta command not found after installation" >&2
    exit 1
fi

# Configure git to use delta as the pager for diffs
echo "Configuring git to use delta..."
cat >> /etc/skel/.gitconfig << 'EOF'
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    line-numbers = true
    side-by-side = true

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
EOF

echo "git-delta installation and configuration complete"