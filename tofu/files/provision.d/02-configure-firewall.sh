#!/bin/bash
set -euo pipefail

echo "Configuring firewalld..."

# Enable and start firewalld
systemctl enable firewalld
systemctl start firewalld

# Configure public zone for public interface (ens10)
firewall-cmd --permanent --zone=public --add-interface=ens10
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-port=6443/tcp

# Configure trusted zone for private network interface (enp7s0)
# Allow all traffic on private network for K3s cluster communication
firewall-cmd --permanent --zone=trusted --add-interface=enp7s0

firewall-cmd --reload

echo "Firewall configuration complete"