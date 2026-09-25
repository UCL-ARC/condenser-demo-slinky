# Create a key pair to access the cluster

resource "tls_private_key" "slurm_cluster_key" {
  algorithm = "ED25519"
}

# Add the public key to the slurm helm chart values file

resource "local_file" "slurm_conf" {
  content = templatefile(
    "${path.module}/slurm.yaml.tftpl",
    {
      public_key = trimspace(tls_private_key.slurm_cluster_key.public_key_openssh)
    }
  )
  filename = "${path.module}/slurm.yaml"
}

# Record the private key so we can use it to access the cluster

resource "local_sensitive_file" "slurm_private_key" {
  content  = tls_private_key.slurm_cluster_key.private_key_openssh
  filename = "${path.module}/id_slurm"
}
