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
├── inventory/
│   ├── hcloud.yml             # Dynamic inventory from Hetzner Cloud
│   ├── group_vars/
│   │   └── all.yml            # Global variables for all hosts
│   └── host_vars/             # Host-specific variables (optional)
├── playbooks/
│   ├── ping.yml               # Test connectivity
│   └── update-known-hosts.yml # Update SSH fingerprints
└── roles/                     # Custom roles (future)
```

## Quick Start

1. **Run setup** (if not already done):
   ```bash
   mise run setup
   ```

2. **Deploy infrastructure** (SSH fingerprints updated automatically):
   ```bash
   mise run tofu:apply
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

### Update SSH Known Hosts (Manual)

SSH fingerprints are automatically updated by OpenTofu when infrastructure changes. However, you can manually update them if needed:
```bash
mise run ansible:update-known-hosts
```

### Deploy K3s Cluster

Deploy a 3-node HA K3s cluster with embedded etcd:
```bash
mise run ansible:deploy-k3s
```

This will:
- Install K3s on all nodes
- Configure HA with embedded etcd
- Set up TLS SANs for the floating IP
- Retrieve kubeconfig to `/tmp/k3s-kubeconfig.yaml`

After deployment:
```bash
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
kubectl get nodes
```

### Run Custom Playbooks

```bash
mise run ansible:run playbooks/your-playbook.yml
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
op run -- ansible-playbook playbooks/ping.yml --limit k3s-converged-node-01
```
