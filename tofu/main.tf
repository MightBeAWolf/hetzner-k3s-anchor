# Reference existing SSH Key
data "hcloud_ssh_key" "anchor_ssh_key" {
  name = var.ssh_key_name
}

# Private Network
resource "hcloud_network" "k3s_network" {
  name     = "k3s-network"
  ip_range = "192.168.0.0/16"
}

# Network Subnet
resource "hcloud_network_subnet" "k3s_subnet" {
  type         = "cloud"
  network_id   = hcloud_network.k3s_network.id
  network_zone = var.network_zone
  ip_range     = "192.168.1.0/24"
}

# Floating IP
resource "hcloud_floating_ip" "k3s_floating_ip" {
  type          = "ipv4"
  home_location = var.location
  name          = "k3s-floating-ip"
}

# Cloud Firewall
resource "hcloud_firewall" "k3s_firewall" {
  name = "k3s-firewall"

  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = [
      var.allowed_admin_cidr
    ]
  }

  rule {
    direction = "in"
    port      = "6443"
    protocol  = "tcp"
    source_ips = [
      var.allowed_admin_cidr
    ]
  }

  rule {
    direction = "in"
    port      = "80"
    protocol  = "tcp"
    source_ips = [
      var.allowed_admin_cidr,
      "192.168.0.0/16"
    ]
  }

  rule {
    direction = "in"
    port      = "443"
    protocol  = "tcp"
    source_ips = [
      var.allowed_admin_cidr,
      "192.168.0.0/16"
    ]
  }

  rule {
    direction = "in"
    port      = "any"
    protocol  = "tcp"
    source_ips = [
      "192.168.0.0/16"
    ]
  }

  rule {
    direction = "in"
    port      = "any"
    protocol  = "udp"
    source_ips = [
      "192.168.0.0/16"
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "192.168.0.0/16"
    ]
  }
}

# K3s Nodes
resource "hcloud_server" "k3s_nodes" {
  count       = 3
  name        = "k3s-converged-node-${format("%02d", count.index + 1)}"
  image       = "debian-12"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.anchor_ssh_key.id]

  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    path_module = path.module
  })

  network {
    network_id = hcloud_network.k3s_network.id
    ip         = "192.168.1.${count.index + 2}"
  }

  depends_on = [hcloud_network_subnet.k3s_subnet]
}

# Assign Floating IP to first node (unmanaged for kube-vip takeover)
resource "hcloud_floating_ip_assignment" "k3s_floating_ip_assignment" {
  floating_ip_id = hcloud_floating_ip.k3s_floating_ip.id
  server_id      = hcloud_server.k3s_nodes[0].id

  lifecycle {
    ignore_changes = [server_id]
  }
}