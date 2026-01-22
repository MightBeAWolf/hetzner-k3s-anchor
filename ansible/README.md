# Ansible Configuration

This directory contains Ansible playbooks, roles, and configuration for managing the Anchor project infrastructure.

## Prerequisites

All dependencies are managed via mise. Simply run:

```bash
mise run setup
```

This will:
- Install Ansible and OpenTofu via mise
- Initialize OpenTofu configuration
- Install required Ansible collections from `requirements.yml`

**Note**: Ensure 1Password CLI is configured before running setup:
```bash
op --version
```

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Ansible Galaxy dependencies
├── inventory/
│   ├── hcloud.yml             # Dynamic inventory from Hetzner Cloud
│   └── group_vars/
│       └── all.yml            # Global variables for all hosts
├── playbooks/
│   ├── 01-infrastructure.yml  # Full infrastructure deployment (orchestrator)
│   ├── 02-platform.yml        # Platform services (database)
│   ├── infrastructure/        # Modular infrastructure playbooks
│   │   ├── k3s-cluster.yml        # K3s HA cluster
│   │   ├── hcloud-integrations.yml # Hetzner CCM + CSI
│   │   └── cert-manager.yml       # TLS certificate management
│   └── maintenance/           # Maintenance playbooks
│       ├── ping.yml               # Test connectivity
│       ├── uninstall-k3s.yml      # Cluster teardown
│       └── update-known-hosts.yml # Update SSH fingerprints
└── roles/
    ├── infrastructure/        # Infrastructure roles
    │   ├── hcloud_facts/          # Fetch Hetzner Cloud facts
    │   ├── k3s_server/            # K3s installation (CIS hardened)
    │   ├── k3s_kubeconfig/        # Kubeconfig retrieval
    │   ├── hcloud_ccm/            # Hetzner Cloud Controller Manager
    │   ├── hcloud_csi/            # Hetzner CSI Driver
    │   └── cert_manager/          # cert-manager with Let's Encrypt
    ├── platform/              # Platform roles
    │   └── database/              # CloudNativePG PostgreSQL
    └── system/                # System roles
        └── helm/                  # Helm installation
```

## Quick Start

1. **Run setup** (if not already done):
   ```bash
   mise run setup
   ```

2. **Deploy full stack** (single 1Password prompt):
   ```bash
   mise run deploy:full
   ```

   Or deploy step-by-step:
   ```bash
   mise run tofu:apply           # Infrastructure
   mise run ansible:deploy-k3s   # K3s + integrations
   mise run ansible:deploy-platform  # Database
   ```

3. **Test connectivity**:
   ```bash
   mise run ansible:ping
   ```

## Usage

### View Inventory

View all discovered hosts from Hetzner Cloud:
```bash
mise run ansible:inventory
```

### Test Connectivity

Verify Ansible can connect to all hosts:
```bash
mise run ansible:ping
```

### Deploy Infrastructure

Deploy the complete K3s infrastructure stack:
```bash
mise run ansible:deploy-k3s
```

This orchestrates three sub-playbooks:
1. `infrastructure/k3s-cluster.yml` - K3s HA cluster with embedded etcd
2. `infrastructure/hcloud-integrations.yml` - Hetzner CCM and CSI Driver
3. `infrastructure/cert-manager.yml` - TLS certificates with Let's Encrypt

### Deploy Individual Components

Each infrastructure component can be deployed independently:
```bash
# K3s cluster only
mise run ansible:deploy-cluster

# Hetzner CCM + CSI only (requires K3s)
mise run ansible:deploy-hcloud

# cert-manager only (requires K3s)
mise run ansible:deploy-cert-manager
```

### Deploy Platform Services

Deploy platform services after infrastructure is ready:
```bash
mise run ansible:deploy-platform
```

### Run Custom Playbooks

```bash
mise run ansible:run playbooks/infrastructure/cert-manager.yml
```

## Dynamic Inventory

The inventory is dynamically generated from Hetzner Cloud using server labels:
- Filters: `project=anchor` AND `role=k3s-node`
- Groups created automatically based on labels and server attributes
- See `inventory/hcloud.yml` for full configuration

## Configuration Highlights

- **SSH**: Uses 1Password SSH agent (no private key files)
- **Fact Caching**: Facts cached to `/tmp/ansible_facts` for 1 hour
- **Output**: YAML format with task timing
- **Python**: Auto-detected on remote hosts
- **Diffs**: Always shown for transparency

See `ansible.cfg` for full configuration details.

## Role-Based Architecture

Infrastructure deployment uses modular, reusable roles:

| Role | Description |
|------|-------------|
| `infrastructure/hcloud_facts` | Fetches Load Balancer IP and network name from Hetzner API |
| `infrastructure/k3s_server` | K3s installation with CIS hardening (handles init + join) |
| `infrastructure/k3s_kubeconfig` | Retrieves and saves kubeconfig locally |
| `infrastructure/hcloud_ccm` | Hetzner Cloud Controller Manager deployment |
| `infrastructure/hcloud_csi` | Hetzner CSI Driver for persistent volumes |
| `infrastructure/cert_manager` | cert-manager with Let's Encrypt and Cloudflare DNS-01 |
| `platform/database` | CloudNativePG PostgreSQL cluster |
| `system/helm` | Helm installation |

## Common Tasks

### Run ad-hoc commands

```bash
cd ansible
op run -- ansible all -m shell -a "uptime"
```

### Gather facts

```bash
cd ansible
op run -- ansible all -m setup
```

### Limit to specific hosts

```bash
cd ansible
op run -- ansible-playbook playbooks/maintenance/ping.yml --limit k3s-converged-node-01
```
