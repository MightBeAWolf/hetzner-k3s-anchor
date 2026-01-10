#!/bin/bash
set -euo pipefail

echo "Installing bat..."

# Update package list
apt-get update

# Install bat (installs as batcat on Debian)
apt-get install -y bat

# Verify batcat is installed
if ! command -v batcat >/dev/null 2>&1; then
    echo "Error: batcat installation failed" >&2
    exit 1
fi

# Create symlink for bat command (Debian installs as batcat)
echo "Creating bat symlink for batcat..."
ln -s /usr/bin/batcat /usr/local/bin/bat

# Verify installation
if command -v bat >/dev/null 2>&1; then
    BAT_VERSION=$(bat --version)
    echo "Successfully installed: $BAT_VERSION"
else
    echo "Error: bat command not available after setup" >&2
    exit 1
fi

echo "bat installation complete"