variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "server_type" {
  description = "Hetzner Cloud server type for K3s nodes"
  type        = string
  default     = "cx23"
}

variable "allowed_admin_cidr" {
  description = "CIDR block allowed for SSH and K8s API access"
  type        = string
  default     = "73.97.54.81/32"
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "hel1"
}

variable "network_zone" {
  description = "Hetzner Cloud network zone"
  type        = string
  default     = "eu-central"
}

variable "ssh_key_name" {
  description = "Name of the SSH key in Hetzner Cloud"
  type        = string
}

