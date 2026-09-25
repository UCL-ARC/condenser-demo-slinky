# Put your input variables here
variable "k3s_namespace" {
  type        = string
  description = "Namespace to deploy the cluster node VMs in."
}

variable "k3s_network" {
  type        = string
  description = "Network for the cluster VMs to use. namespace/network_name"
}

variable "k3s_api_vip" {
  type        = string
  description = "IPv4 address for the k3s cluster VIP."
}

variable "k3s_node_ips" {
  type        = list(string)
  description = "IPv4 addresses for the k3s cluster nodes."
}

variable "k3s_gateway_ip" {
  type        = string
  description = "IPv4 address for the network's router."
}

variable "k3s_dns_ip" {
  type        = string
  description = "IPv4 address for the network's DNS server."
}

variable "k3s_ssh_common_args" {
  type        = string
  description = "Arguments for SSH that enable Ansible to connect from the Terraform agent to the k3s cluster node VMs."
}

variable "slurm_login_ip" {
  type        = string
  description = "IPv4 address for the Slurm cluster login service."
}
