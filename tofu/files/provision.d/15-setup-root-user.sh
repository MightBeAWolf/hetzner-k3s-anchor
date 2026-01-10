#!/bin/bash
set -euo pipefail

echo "Setting up root user environment..."

# Copy skeleton files to root user
echo "Copying skeleton files to root user home directory..."

# Copy .fzf directory if it exists
if [ -d "/etc/skel/.fzf" ]; then
    echo "Installing FZF for root user..."
    cp -r /etc/skel/.fzf /root/
    chmod +x /root/.fzf/bin/fzf 2>/dev/null || true
fi

# Copy .bashrc additions from skel
if [ -f "/etc/skel/.bashrc" ]; then
    echo "Updating root .bashrc with skeleton configurations..."
    
    # Extract FZF configuration from skel .bashrc
    if grep -q "fzf" /etc/skel/.bashrc; then
        echo "Adding FZF integration to root .bashrc..."
        echo '' >> /root/.bashrc
        echo '# FZF integration' >> /root/.bashrc
        grep -A 15 "fzf" /etc/skel/.bashrc >> /root/.bashrc
    fi
    
    # Extract Starship configuration from skel .bashrc
    if grep -q "starship" /etc/skel/.bashrc; then
        echo "Adding Starship integration to root .bashrc..."
        echo '' >> /root/.bashrc
        echo '# Enable the Starship prompt' >> /root/.bashrc
        grep "starship" /etc/skel/.bashrc >> /root/.bashrc
    fi
fi

# Copy .gitconfig if it exists
if [ -f "/etc/skel/.gitconfig" ]; then
    echo "Copying git configuration to root user..."
    cp /etc/skel/.gitconfig /root/
fi

# Copy fonts if they exist
if [ -d "/etc/skel/.local/share/fonts" ]; then
    echo "Copying fonts to root user..."
    mkdir -p /root/.local/share/fonts
    cp -r /etc/skel/.local/share/fonts/* /root/.local/share/fonts/ 2>/dev/null || true
fi

echo "Root user environment setup complete"