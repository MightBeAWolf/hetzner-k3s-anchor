#!/bin/bash
set -euo pipefail

echo "Configuring firewalld..."

# Enable and start firewalld
systemctl enable firewalld
systemctl start firewalld

# Configure firewalld rules
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --zone=public --add-interface=ens10
firewall-cmd --reload

echo "Firewall configuration complete"