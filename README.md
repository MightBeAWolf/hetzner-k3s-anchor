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
├── ansible/                 # Ansible configuration management
│   ├── ansible.cfg          # Ansible configuration
│   ├── requirements.yml     # Ansible Galaxy dependencies
│   ├── inventory/           # Dynamic inventory from Hetzner Cloud
│   ├── playbooks/           # Ansible playbooks
│   └── roles/               # Custom Ansible roles
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
# Setup project (installs tools, initializes OpenTofu, installs Ansible collections)
mise run setup

# Review planned changes
mise run tofu:plan
```

This will:
- Install OpenTofu and Ansible via mise
- Initialize OpenTofu backend
- Install required Ansible collections (hetzner.hcloud, community.general, ansible.posix)

## Infrastructure Overview

### Resources Provisioned
- **3x Hetzner Cloud Servers** (cx23, Debian 12)
  - `k3s-converged-node-01` (192.168.1.2)
  - `k3s-converged-node-02` (192.168.1.3)
  - `k3s-converged-node-03` (192.168.1.4)
  - Labeled: `project=anchor`, `environment=production`, `role=k3s-node`
- **Private Network** (192.168.0.0/16, labeled for CCM discovery)
- **Load Balancer** (for K3s API HA endpoint)
- **Cloud Firewall** (restricted access)

### Kubernetes Components
- **K3s** (v1.31.4+k3s1) - Lightweight Kubernetes distribution
- **Hetzner Cloud Controller Manager** - Node lifecycle and LoadBalancer provisioning
- **kube-router** - NetworkPolicy controller
- **etcd encryption** - Secrets encrypted at rest with AES-CBC

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
# Deploy all resources (SSH known_hosts updated automatically)
mise run tofu:apply

# Test Ansible connectivity
mise run ansible:ping
```

### Manage Infrastructure
```bash
# Validate configuration
mise run tofu:validate

# Format code
mise run tofu:fmt

# Lint and validate
mise run tofu:lint

# Destroy infrastructure
mise run tofu:destroy
```

### Ansible Configuration Management
```bash
# View dynamic inventory from Hetzner Cloud
mise run ansible:inventory

# Run connectivity test
mise run ansible:ping

# Update SSH known_hosts
mise run ansible:update-known-hosts

# Deploy K3s HA cluster
mise run ansible:deploy-k3s

# Run a custom playbook
mise run ansible:run playbooks/your-playbook.yml
```

See [ansible/README.md](ansible/README.md) for detailed Ansible documentation.

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
| `k3s_token` | - | K3s cluster token for node authentication (from 1Password) |
| `server_type` | `cx23` | Hetzner server type |
| `allowed_admin_cidr` | `73.97.54.81/32` | Admin access CIDR |
| `location` | `hel1` | Hetzner datacenter location |
| `network_zone` | `eu-central` | Network zone for resources |
| `k3s_version` | `v1.31.4+k3s1` | K3s version to install |

## Outputs

After deployment, retrieve connection details:
```bash
# Get node public IPs
op run -- tofu -chdir=tofu output node_public_ips

# Get node private IPs
op run -- tofu -chdir=tofu output node_private_ips

# Get Load Balancer IP (control plane endpoint)
op run -- tofu -chdir=tofu output load_balancer_ip

# Get specific node IP by index (0-2)
mise run tofu:ip 0  # node-01
mise run tofu:ip 1  # node-02
mise run tofu:ip 2  # node-03

# Or use Ansible inventory
mise run ansible:inventory
```

## Server Access

### SSH into Nodes
After infrastructure deployment, connect to any node using SSH:

```bash
# SSH into specific node by index
ssh "root@$(mise run tofu:ip 0)"  # k3s-converged-node-01
ssh "root@$(mise run tofu:ip 1)"  # k3s-converged-node-02
ssh "root@$(mise run tofu:ip 2)"  # k3s-converged-node-03
```

**Connection Notes:**
- SSH access only works from the configured admin IP (`73.97.54.81/32`)
- SSH authentication uses 1Password SSH agent (no private key files)
- Default user is `root` on Debian 12 instances
- SSH fingerprints are automatically updated in `~/.ssh/known_hosts` when infrastructure changes

## Updating Cloud-Init Configuration

When you modify `cloud-init.yaml`, the changes only apply to newly created servers. To apply cloud-init changes to existing infrastructure:

### Option 1: Recreate All Servers (Recommended)
```bash
# Force recreation of all servers with new cloud-init
mise run tofu:replace-nodes

# Verify connectivity
mise run ansible:ping
```

**Note:** This task automatically:
- Clears Ansible fact cache
- Recreates all three servers
- Reassigns the floating IP to the new node-01
- Updates SSH fingerprints in ~/.ssh/known_hosts

### Option 2: Use Ansible for Configuration Changes
For runtime configuration changes without server recreation:

```bash
# Create a playbook in ansible/playbooks/ and run it
mise run ansible:run playbooks/your-config-changes.yml
```

### Option 3: Manual Application
If you need to apply specific changes without recreating servers:

```bash
# SSH into each node and apply changes manually
ssh "root@$(mise run tofu:ip 0)"
ssh "root@$(mise run tofu:ip 1)"
ssh "root@$(mise run tofu:ip 2)"

# Example: Fix firewall zone configuration
firewall-cmd --permanent --zone=public --add-interface=ens10
firewall-cmd --reload
```

**Important Notes:**
- Option 1 will cause downtime as servers are recreated
- Option 2 is preferred for runtime configuration management
- Option 3 requires manual verification on each node
- Always test changes in a development environment first

## K3s Deployment

After infrastructure is provisioned, deploy the K3s HA cluster:

```bash
# Deploy K3s to all nodes (includes CCM and kube-router)
mise run ansible:deploy-k3s

# Configure kubeconfig (automatically saved to ./kubeconfig)
export KUBECONFIG=./kubeconfig

# Verify cluster
kubectl get nodes -o wide
kubectl cluster-info

# Verify CCM is running
kubectl get pods -n kube-system -l app=hcloud-cloud-controller-manager

# Test LoadBalancer provisioning
kubectl create deployment test-nginx --image=nginx
kubectl expose deployment test-nginx --type=LoadBalancer --port=80
kubectl get svc test-nginx -w  # Wait for EXTERNAL-IP
```

## Next Steps

K3s cluster is now operational. Next phases:
1. ✅ **Phase 1**: Infrastructure Provisioning (Complete)
2. ✅ **Phase 2**: K3s cluster installation with Hetzner CCM (Complete)
3. **Phase 3**: Application workload deployment

## Security Notes

- Pod Security Admission enforces "restricted" policy
- etcd secrets encrypted at rest with AES-CBC
- NetworkPolicies enforced via kube-router
- Google Authenticator 2FA configuration deferred for manual setup
- All firewall rules use allow-list approach