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
- **Bootstrap**: cloud-init.yaml configures Debian 12 with firewalld, fail2ban, SSH hardening

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