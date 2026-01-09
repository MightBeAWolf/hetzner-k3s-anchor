output "node_public_ips" {
  description = "Public IPv4 addresses of all K3s nodes"
  value       = hcloud_server.k3s_nodes[*].ipv4_address
}

output "node_private_ips" {
  description = "Private IPv4 addresses of all K3s nodes"
  value       = [for server in hcloud_server.k3s_nodes : tolist(server.network)[0].ip]
}

output "floating_ip" {
  description = "Floating IP address for high availability"
  value       = hcloud_floating_ip.k3s_floating_ip.ip_address
}

output "node_names" {
  description = "Names of all K3s nodes"
  value       = hcloud_server.k3s_nodes[*].name
}