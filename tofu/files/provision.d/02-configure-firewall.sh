#!/bin/bash
set -euo pipefail

echo "Configuring firewalld..."

# Enable and start firewalld
systemctl enable firewalld
systemctl start firewalld

# Detect public interface (the one used for default route)
PUBLIC_IF=$(ip -4 route show default | head -1 | awk '{print $5}')

# Detect private interface (the one with IP in 192.168.0.0/16 range)
PRIVATE_IF=$(ip -4 addr show | awk '/inet 192.168/ {print $NF}')

echo "Detected public interface: ${PUBLIC_IF}"
echo "Detected private interface: ${PRIVATE_IF}"

# Configure public zone for public interface
firewall-cmd --permanent --zone=public --add-interface="${PUBLIC_IF}"
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-port=6443/tcp

# Configure trusted zone for private network interface
# Allow all traffic on private network for K3s cluster communication
if [ -n "${PRIVATE_IF}" ]; then
  firewall-cmd --permanent --zone=trusted --add-interface="${PRIVATE_IF}"
  echo "Private network interface ${PRIVATE_IF} added to trusted zone"
else
  echo "Warning: Could not detect private network interface"
fi

firewall-cmd --reload

echo "Firewall configuration complete"