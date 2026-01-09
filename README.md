# Anchor Project - Hetzner Cloud K3s Infrastructure

High-Availability Kubernetes cluster infrastructure provisioning using 
OpenTofu and Hetzner Cloud.

## Project Structure

```
.
├── tofu/                    # OpenTofu configuration files
│   ├── versions.tf          # Provider configuration
│   ├── variables.tf         # Input variables
│   ├── main.tf              # Infrastructure resources
│   ├── cloud-init.yaml      # VM bootstrap configuration
│   └── outputs.tf           # Output values
├── mise.toml                # Development workflow tools
├── .pre-commit-config.yaml  # Code quality hooks
├── .yamllint.yaml           # YAML linting configuration
└── README.md                # This file
```

## Prerequisites

1. **Hetzner Cloud Account** with API token
2. **SSH Key** uploaded to Hetzner Cloud 
3. **mise** for tool management: https://mise.jdx.dev/
4. **1Password CLI** for secure secret management

## Setup

### 1. Install Tools
```bash
# Install mise if not already installed
curl https://mise.run | sh

# Install project tools
mise install
```

### 2. Configure 1Password Secrets
Store your secrets in 1Password:
- **Hetzner Cloud Token**: `op://Private/6agth7vqswxvzx7lwmjqyzm25y/credential`
- **SSH Key Name**: `op://Private/6agth7vqswxvzx7lwmjqyzm25y/ssh_key_name`

Environment variables are automatically configured via `mise.toml` and loaded through `op run`.

### 3. Initialize Infrastructure
```bash
# Setup project and initialize OpenTofu
mise run setup

# Review planned changes
mise run plan
```

## Infrastructure Overview

### Resources Provisioned
- **3x Hetzner Cloud Servers** (cx23, Debian 12)
  - `k3s-converged-node-01` (192.168.1.2)
  - `k3s-converged-node-02` (192.168.1.3)  
  - `k3s-converged-node-03` (192.168.1.4)
- **Private Network** (192.168.0.0/16)
- **Floating IP** (for HA, managed by kube-vip)
- **Cloud Firewall** (restricted access)

### Security Configuration
- SSH access restricted to `73.97.54.81/32`
- Password authentication disabled
- Firewalld configured on each node
- Fail2ban installed for intrusion prevention

### Network Access
- **SSH (22)**: Admin IP only
- **K8s API (6443)**: Admin IP only  
- **HTTP/HTTPS (80/443)**: Admin IP + private network
- **Internal**: Full access within private network

## Usage

### Deploy Infrastructure
```bash
# Deploy all resources
mise run apply
```

### Manage Infrastructure
```bash
# Validate configuration
mise run validate

# Format code
mise run fmt

# Lint and validate
mise run lint

# Destroy infrastructure
mise run destroy
```

### Development Workflow
```bash
# Install pre-commit hooks
pre-commit install

# Run pre-commit on all files
pre-commit run --all-files
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hcloud_token` | - | Hetzner Cloud API token (from 1Password) |
| `ssh_key_name` | - | Name of SSH key in Hetzner Cloud (from 1Password) |
| `server_type` | `cx23` | Hetzner server type |
| `allowed_admin_cidr` | `73.97.54.81/32` | Admin access CIDR |
| `location` | `hel1` | Hetzner datacenter location |
| `network_zone` | `eu-central` | Network zone for resources |

## Outputs

After deployment, retrieve connection details:
```bash
# Get node public IPs
op run -- tofu -chdir=tofu output node_public_ips

# Get node private IPs  
op run -- tofu -chdir=tofu output node_private_ips

# Get floating IP
op run -- tofu -chdir=tofu output floating_ip

# Get specific node IP by index (0-2)
mise run ip 0  # node-01
mise run ip 1  # node-02
mise run ip 2  # node-03
```

## Server Access

### SSH into Nodes
After infrastructure deployment, connect to any node using SSH:

```bash
# SSH into specific node by index
ssh "root@$(mise run ip 0)"  # k3s-converged-node-01
ssh "root@$(mise run ip 1)"  # k3s-converged-node-02
ssh "root@$(mise run ip 2)"  # k3s-converged-node-03
```

**Connection Notes:**
- SSH access only works from the configured admin IP (`73.97.54.81/32`)
- Password authentication is disabled - uses SSH key authentication only
- Default user is `root` on Debian 12 instances

## Updating Cloud-Init Configuration

When you modify `cloud-init.yaml`, the changes only apply to newly created servers. To apply cloud-init changes to existing infrastructure:

### Option 1: Recreate All Servers (Recommended)
```bash
# Force recreation of all servers with new cloud-init
mise run replace-nodes
```

**Note:** This task automatically reassigns the floating IP to the new node-01 after recreation.

### Option 2: Manual Application
If you need to apply specific changes without recreating servers:

```bash
# SSH into each node and apply changes manually
ssh "root@$(mise run ip 0)"
ssh "root@$(mise run ip 1)" 
ssh "root@$(mise run ip 2)"

# Example: Fix firewall zone configuration
firewall-cmd --permanent --zone=public --add-interface=ens10
firewall-cmd --reload
```

**Important Notes:**
- Option 1 will cause downtime as servers are recreated
- Option 2 requires manual verification on each node
- Always test changes in a development environment first

## Next Steps

This completes Phase 1 (Infrastructure Provisioning). Next phases:
1. **Phase 2**: K3s cluster installation and configuration
2. **Phase 3**: Kube-VIP setup for HA floating IP management
3. **Phase 4**: Application workload deployment

## Security Notes

- This is infrastructure-only provisioning
- K3s installation not included in this phase
- Google Authenticator 2FA setup deferred for manual configuration
- All firewall rules use allow-list approach