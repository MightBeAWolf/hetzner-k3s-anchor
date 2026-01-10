# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Phase 1 of the Anchor Project - a High-Availability Kubernetes cluster infrastructure provisioning system using OpenTofu and Hetzner Cloud. The project is designed as a polyrepo with isolated state management.

## Architecture

### Infrastructure Stack
- **Cloud Provider**: Hetzner Cloud (eu-central region)
- **Infrastructure as Code**: OpenTofu (in `/tofu/` directory)
- **Target Deployment**: 3-node K3s cluster with HA floating IP
- **Security**: Allow-list firewall rules, SSH key authentication
- **Secret Management**: 1Password CLI integration via `op run`

### Resource Design
- **Networking**: Private network (192.168.0.0/16) with cloud subnet (192.168.1.0/24)
- **Compute**: 3x cx23 servers with static private IPs (.2, .3, .4)
- **HA Setup**: Floating IP initially assigned to node-01 but lifecycle-ignored for kube-vip takeover
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
mise run plan

# Deploy infrastructure
mise run apply

# Destroy infrastructure
mise run destroy

# Validate configuration
mise run validate

# Format code
mise run fmt

# Lint everything
mise run lint

# Replace all nodes with updated cloud-init configuration
mise run replace-nodes
```

### Server Access
```bash
# Get public IP of specific node (0-2)
mise run ip 0  # node-01
mise run ip 1  # node-02
mise run ip 2  # node-03

# SSH into nodes
ssh "root@$(mise run ip 0)"
ssh "root@$(mise run ip 1)"
ssh "root@$(mise run ip 2)"
```

### Infrastructure Outputs
```bash
# Get all node public IPs
op run -- tofu -chdir=tofu output node_public_ips

# Get all node private IPs
op run -- tofu -chdir=tofu output node_private_ips

# Get floating IP
op run -- tofu -chdir=tofu output floating_ip

# Get node names
op run -- tofu -chdir=tofu output node_names
```

### Development Workflow
```bash
# Format and validate
mise run lint

# Run pre-commit checks
pre-commit run --all-files
```

### Secret Management
All commands use `op run --` for 1Password secret injection. Secrets are configured in `mise.toml`:
- `TF_VAR_hcloud_token`: Hetzner Cloud API token
- `TF_VAR_ssh_key_name`: Name of SSH key in Hetzner Cloud

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

**Important**: Changes to cloud-init.yaml or provisioning scripts only apply to newly created servers. Use `mise run replace-nodes` to recreate all nodes with updated configuration.

### Outputs Handling
The `node_private_ips` output uses a for-expression with `tolist()` because the `network` attribute is a set, not a list:
```hcl
value = [for server in hcloud_server.k3s_nodes : tolist(server.network)[0].ip]
```

### Floating IP Lifecycle Management
The floating IP assignment uses `ignore_changes = [server_id]` in its lifecycle block (main.tf:124-126). This is intentional:
- Initial assignment: OpenTofu assigns floating IP to node-01
- Runtime management: kube-vip takes over floating IP management for HA failover
- OpenTofu won't fight kube-vip by reverting the assignment back to node-01

**Important**: When using `mise run replace-nodes`, the task explicitly re-assigns the floating IP to the new node-01 after server recreation.

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

### Phase Scope
This is **Phase 1 only** - infrastructure provisioning. K3s installation, kube-vip setup, and application deployment are future phases. Do not implement Kubernetes components in this phase.

## Tool Requirements

Always run `mise install` before working. The project uses:
- OpenTofu (latest)
- pre-commit (3.8.0)
- 1Password CLI (for secret management)

## Validation Commands

After any changes, run:
1. `mise run lint` - formats and validates
2. `mise run plan` - verify infrastructure changes
3. `pre-commit run --all-files` - code quality checks

## Pre-commit Hooks

The project uses pre-commit for code quality. Hooks include:
- **Standard checks**: trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files, check-merge-conflict
- **Terraform/OpenTofu**: terraform_fmt, terraform_validate, terraform_tflint (with extensive rule set)
- **YAML linting**: yamllint with custom configuration (.yamllint.yaml)

Install hooks with `pre-commit install` (optional, runs automatically in CI)