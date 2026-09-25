# A k3s cluster for Slurm to run in

module "k3s_cluster" {
  source = "github.com/UCL-ARC/terraform-harvester-modules//modules/k3s-cluster?ref=0.0.41"

  cluster_name            = "slurm-infra"
  cluster_api_vip         = var.k3s_api_vip
  cluster_additional_vips = [var.slurm_login_ip] # For login service
  namespace               = var.k3s_namespace
  networks = {
    eth0 = {
      ips     = var.k3s_node_ips
      cidr    = 24
      gateway = var.k3s_gateway_ip
      dns     = var.k3s_dns_ip
      network = var.k3s_network
    }
  }
  vm_image           = "almalinux-9.8"
  vm_image_namespace = "harvester-public"
  vm_username        = "almalinux"

  vm_tags = {}

  ssh_common_args = var.k3s_ssh_common_args
}
