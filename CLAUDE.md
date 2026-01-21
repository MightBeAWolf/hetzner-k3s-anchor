# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Phase 1 of the Anchor Project - a High-Availability Kubernetes cluster infrastructure provisioning system using OpenTofu and Hetzner Cloud. The project is designed as a polyrepo with isolated state management.

## Architecture

### Infrastructure Stack
- **Cloud Provider**: Hetzner Cloud (hel1 region)
- **Infrastructure as Code**: OpenTofu (in `/tofu/` directory)
- **Configuration Management**: Ansible (in `/ansible/` directory) with Hetzner Cloud dynamic inventory
- **Kubernetes**: 3-node K3s HA cluster with embedded etcd
- **Cloud Controller**: Hetzner CCM for LoadBalancer services and node lifecycle
- **HA Endpoint**: Hetzner Load Balancer for K3s API
- **Security**: Allow-list firewall rules, SSH key authentication via 1Password SSH agent
- **Secret Management**: 1Password CLI integration via `op run`

### Resource Design
- **Networking**: Private network (192.168.0.0/16) with cloud subnet (192.168.1.0/24), labeled `project=anchor`
- **Compute**: 3x cx23 servers with static private IPs (.2, .3, .4)
- **Server Labels**: All servers tagged with `project=anchor`, `environment=production`, `role=k3s-node`, and `node_index`
- **HA Setup**: Hetzner Load Balancer fronts K3s API on port 6443
- **Bootstrap**: cloud-init.yaml configures Debian 12 with modular provisioning scripts

## Essential Commands

### Project Setup
```bash
# Initial setup
mise run setup

# Install tools only
mise install
```

### Infrastructure Operations
```bash
# Plan changes (always run first)
mise run tofu:plan

# Deploy infrastructure
mise run tofu:apply

# Destroy infrastructure
mise run tofu:destroy

# Validate configuration
mise run tofu:validate

# Format code
mise run tofu:fmt

# Lint everything
mise run tofu:lint

# Replace all nodes with updated cloud-init configuration
mise run tofu:replace-nodes
```

### Server Access
```bash
# Get public IP of specific node (0-2)
mise run tofu:ip 0  # node-01
mise run tofu:ip 1  # node-02
mise run tofu:ip 2  # node-03

# SSH into nodes
ssh "root@$(mise run tofu:ip 0)"
ssh "root@$(mise run tofu:ip 1)"
ssh "root@$(mise run tofu:ip 2)"
```

### Infrastructure Outputs
```bash
# Get all node public IPs
op run -- tofu -chdir=tofu output node_public_ips

# Get all node private IPs
op run -- tofu -chdir=tofu output node_private_ips

# Get Load Balancer IP (control plane endpoint)
op run -- tofu -chdir=tofu output load_balancer_ip

# Get node names
op run -- tofu -chdir=tofu output node_names
```

### Ansible Operations
```bash
# View dynamic inventory from Hetzner Cloud
mise run ansible:inventory

# Test connectivity to all hosts
mise run ansible:ping

# Update SSH known_hosts with current server fingerprints
mise run ansible:update-known-hosts

# Deploy K3s HA cluster
mise run ansible:deploy-k3s

# Run a specific playbook
mise run ansible:run playbooks/your-playbook.yml
```

### Development Workflow
```bash
# Format and validate
mise run tofu:lint

# Run pre-commit checks
pre-commit run --all-files
```

### Secret Management
All commands use `op run --` for 1Password secret injection. Secrets are configured in `mise.toml`:
- `HCLOUD_TOKEN`: Hetzner Cloud API token (used by both OpenTofu and Ansible)
- `TF_VAR_hcloud_token`: References `$HCLOUD_TOKEN` for OpenTofu
- `TF_VAR_ssh_key_name`: Name of SSH key in Hetzner Cloud
- `K3S_TOKEN`: K3s cluster token for node authentication
- `K3S_ETCD_SECRET`: AES-CBC encryption key for etcd secrets (generated with `head -c 32 /dev/urandom | base64`)

SSH authentication uses the 1Password SSH agent (no private key file needed).

## Critical Implementation Details

### Cloud-Init Provisioning Architecture
The bootstrap process uses a modular script architecture in `/tofu/files/provision.d/`:
- **01-configure-idle-timeout.sh**: Sets TMOUT for automatic logout
- **02-configure-firewall.sh**: Configures firewalld zones and rules
- **03-configure-fail2ban.sh**: Sets up fail2ban with systemd journal integration
- **10-install-bat.sh**: Installs bat (better cat)
- **11-install-fzf.sh**: Installs fzf fuzzy finder
- **12-install-git-delta.sh**: Installs git-delta for better diffs
- **13-install-helix.sh**: Installs Helix editor
- **14-install-starship.sh**: Installs Starship prompt
- **15-setup-root-user.sh**: Configures root user environment
- **20-configure-automatic-updates.sh**: Sets up unattended-upgrades
- **21-configure-disk-cleanup.sh**: Configures automatic disk cleanup
- **22-configure-log-rotation.sh**: Sets up log rotation policies
- **30-setup-services.sh**: Enables and starts system services

Scripts are executed in sorted order (01, 02, 03... 30). The cloud-init.yaml template dynamically includes all `.sh` files using Terraform's `fileset()` function.

**Important**: Changes to cloud-init.yaml or provisioning scripts only apply to newly created servers. Use `mise run tofu:replace-nodes` to recreate all nodes with updated configuration.

### Outputs Handling
The `node_private_ips` output uses a for-expression with `tolist()` because the `network` attribute is a set, not a list:
```hcl
value = [for server in hcloud_server.k3s_nodes : tolist(server.network)[0].ip]
```

### State Isolation
- All OpenTofu files are in `/tofu/` directory
- Use `dir = "tofu"` in mise tasks for proper working directory
- This enables polyrepo architecture with independent state management

### Security Constraints
- Admin access restricted to `73.97.54.81/32`
- HTTP/HTTPS ports (80/443) only accessible from admin IP and private network
- SSH hardened with password authentication disabled
- Google Authenticator 2FA configuration deferred for manual setup

### Firewall Architecture
**Two-layer security model**:
1. **Hetzner Cloud Firewall** (hcloud_firewall.k3s_firewall):
   - SSH (22): Admin IP only
   - K8s API (6443): Admin IP only
   - HTTP/HTTPS (80/443): Admin IP + private network (192.168.0.0/16)
   - Internal: Full TCP/UDP/ICMP within private network
2. **Per-node firewalld** (configured via provision script 02-configure-firewall.sh):
   - Additional host-level protection
   - Configured during cloud-init bootstrap

### Ansible Architecture
- **Dynamic Inventory**: Uses `hetzner.hcloud` collection to query Hetzner Cloud API directly
- **Server Discovery**: Filters servers by labels (`project=anchor`, `role=k3s-node`)
- **Fact Caching**: Caches facts to `/tmp/ansible_facts` for 1 hour (cleared on `tofu:apply` and `tofu:replace-nodes`)
- **SSH Authentication**: Uses 1Password SSH agent (no private key files)
- **SSH Known Hosts**: Automatically updated by OpenTofu via `null_resource` provisioner when servers change
- **Configuration**: All settings in `ansible/ansible.cfg`, global variables in `ansible/inventory/group_vars/all.yml`

**Inventory groups created automatically**:
- `k3s_nodes`: All nodes with role=k3s-node
- `production`: All nodes with environment=production
- `anchor`: All nodes with project=anchor
- `type_cx23`: Grouped by server type
- `status_running`: Grouped by status

### K3s etcd Encryption
The cluster implements encryption-at-rest for Kubernetes secrets in etcd using AES-CBC encryption:
- **Encryption Key**: Managed via `K3S_ETCD_SECRET` environment variable in 1Password
- **Configuration**: Template at `ansible/playbooks/templates/etcd-encryption-config.yml.j2`
- **Deployment Location**: `/var/lib/rancher/k3s/server/cred/encryption-config.yml` (mode 0600)
- **K3s Integration**: Applied via `--kube-apiserver-arg=encryption-provider-config` flag
- **Resources Encrypted**: All Kubernetes Secret resources
- **Fallback**: Identity provider for backward compatibility with unencrypted data

The encryption configuration is deployed during K3s installation on all server nodes. The directory `/var/lib/rancher/k3s/server/cred/` is created with mode 0700 for secure storage.

### Hetzner Cloud Controller Manager (CCM)
The cluster uses Hetzner CCM for cloud provider integration:
- **Deployment**: Applied via `kubectl apply` from a single node (not auto-deploy manifests)
- **Location**: Configured via `HCLOUD_LOAD_BALANCERS_LOCATION` environment variable
- **Features**: Node lifecycle management, LoadBalancer service provisioning, route management
- **Network Discovery**: Uses label selector `project=anchor` to find the Hetzner network
- **Templates**: Located in `ansible/playbooks/templates/ccm/`
  - `00-hcloud-secret.yaml.j2` - API token and network name
  - `10-hcloud-ccm.yaml.j2` - ServiceAccount, RBAC, and Deployment

### Phase Scope
Phases 1 and 2 are complete. Infrastructure provisioning and K3s cluster with CCM are operational.

## Tool Requirements

Always run `mise install` before working. The project uses:
- OpenTofu (latest)
- pre-commit (3.8.0)
- 1Password CLI (for secret management)

## Validation Commands

After any changes, run:
1. `mise run tofu:lint` - formats and validates
2. `mise run tofu:plan` - verify infrastructure changes
3. `pre-commit run --all-files` - code quality checks
4. `mise run ansible:ping` - verify Ansible connectivity (after infrastructure is deployed)

## Pre-commit Hooks

The project uses pre-commit for code quality. Hooks include:
- **Standard checks**: trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files, check-merge-conflict
- **Terraform/OpenTofu**: terraform_fmt, terraform_validate, terraform_tflint (with extensive rule set)
- **YAML linting**: yamllint with custom configuration (.yamllint.yaml)

Install hooks with `pre-commit install` (optional, runs automatically in CI)