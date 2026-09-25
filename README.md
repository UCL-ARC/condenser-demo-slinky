# condenser-demo-slinky

## Slurm on Condenser

This repository contains Terraform modules to deploy a k3s cluster, and instructions to install the Slinky operator to run Slurm.

Put another way, this is a tutorial to quickly stand up Slurm on kubernetes on VMs on kubernetes.

The toolchain goes something like:

``` text
Slurm > Slinky > k3s > Harvester
```

This module uses the [terraform-harvester-modules](https://github.com/UCL-ARC/terraform-harvester-modules/blob/main/README.md#k3s-cluster-module) k3s cluster module to deploy a small k3s cluster with 3 control plane nodes. Then a YAML file is installed to configure the Slurm operator. Several CRDs and the Slurm operator are installed with Helm. Then the Slurm cluster is ready to operate.

### Terminology

The following instructions refer to three different clusters. They are:

1. A Condenser cluster, such as `sl-p02`. VMs run in this cluster.
1. A k3s cluster. The k3s cluster connects VMs that run in the Condenser cluster.
1. A Slurm cluster. The Slurm cluster connects worker pods inside the k3s cluster that runs on VMs in the Condenser cluster.

## Prerequisites

Access to Condenser and sufficient resource quota to deploy 3 VMs each with 4 CPU, 16 Gi RAM, and 30 Gi volumes.

Ansible, later than version 2.16.0, must be installed on the computer where Terraform runs to use the `terraform-harvester-modules/k3s-cluster` module.

## Deploying the k3s cluster on Condenser VMs

> [!NOTE]  
> You do not need to use the `terraform-harvester-modules/k3s-cluster` module; you can create some VMs and [follow the k3s documentation](https://docs.k3s.io/installation) to create a kubernetes cluster, then pick up these instructions from the next section. However the module is a useful example because the k3s cluster will be configured correctly. You can [take a look at the module](https://github.com/UCL-ARC/terraform-harvester-modules/tree/main/modules/k3s-cluster) to see how the k3s cluster is set up.

Configure the `KUBECONFIG` variable with your kubeconfig file, e.g.:

``` sh
export KUBECONFIG=path/to/kubeconfig.yaml
```

The kubeconfig file should provide authentication to a cluster in Condenser. For example, with the kubeconfig file configured you should be able to run a command such as

```sh
kubectl get vmi -n namespace-ns
```

to list the VMs that are running in your namespace on the Condenser cluster. The Condenser documentation provides [instructions for obtaining a kubeconfig file](https://condenser.arc.ucl.ac.uk/documentation/troubleshooting/kubeconfig/).

Clone this repository. Create a file called `terraform.tfvars` in the repository. Populate the `tfvars` file as follows:

``` hcl
k3s_namespace       = "namespace-ns" # Name of a tenant namespace
k3s_network         = "namespace-ns/default" # Tenant network
k3s_api_vip         = "10.0.0.16" # Replace with an IP address in your tenant network
k3s_node_ips        = ["10.0.0.13", "10.0.0.14", "10.0.0.15"] # Replace with IP addresses in your tenant network
k3s_gateway_ip      = "10.0.0.1" # Replace with the gateway address for your tenant network
k3s_dns_ip          = "10.0.0.1" # Replace with the DNS server address for your tenant network
k3s_ssh_common_args = "-o ProxyCommand=\"ssh -W %h:%p condenser\"" # This will work if your SSH configuration has configured Condenser's SSH bastion as a host named 'condenser'
slurm_login_ip      = "10.0.0.17" # Replace with an IP address in your tenant network
```

Deploy the module with the usual sequence of:

``` sh
terraform plan
terraform apply
> yes
```

The module will use Ansible to configure the k3s cluster. Ansible is sensitive to network interruptions. If you recieve errors like:

``` text
TASK [Wait for VM] *************************************************************
│ [ERROR]: Task failed: Action failed: timed out waiting for ping module test: Failed to connect to the host via ssh: Connection closed
```

Then you can try `terraform apply` again. You may need to apply a few times before the configuration succeeds. Ansible makes immutable configuration changes, which means that it is safe to apply over again.

Check that the k3s cluster is correctly deployed:

1. In your namespace on Condenser, three VMs have been deployed named `slurm-infra-control-[0,1,2]`. Each VM has an IPv4 address that starts with `10.134`.
1. Terraform reports a successful application of all resources after running `terraform apply`.

## Installing the `slurm.yaml` configuration file

After the k3s cluster is deployed you can log onto it like so:

``` sh
# From your local computer
ssh -J condenser \
  -i .terraform/modules/k3s_cluster/modules/k3s-cluster/provision/ansible/ssh-private-key \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  almalinux@<K3S NODE IP>
```

Where `<K3S NODE IP>` is one of the node IP addresses you assigned to the k3s cluster VMs.

While logged in to the VM, escalate your privileges and edit the bashrc file.

```sh
# From the k3s cluster VM
sudo -i
vi .bashrc
```

Add these lines to the bashrc file:

```sh
alias k=/usr/local/bin/kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

Then log out of the VM. These additions will ensure that kubectl is available and configured with the kubeconfig file for the k3s cluster when you log in to the root account of the k3s cluster VM.

On your local computer, the Terraform module will have created a file in the repository root titled `slurm.yaml`. The contents of the file will be:

```yaml
---
{
  partitions: {
    all: {
      enabled: true,
    },
  },
  nodesets: {
    slinky: {},
  },
  loginsets: {
    slinky: {
      enabled: true,
      rootSshAuthorizedKeys: "<SSH PUBLIC KEY>",
    },
  },
}

```

Where `<SSH PUBLIC KEY>` is the SSH public key data for a key pair managed by Terraform. This key pair will be used to access the Slurm cluster. This file contains Helm chart values for configuring the Slurm Helm chart.

Use SCP to copy this file onto the k3s cluster:

``` sh
# On your local computer
scp -J condenser \
  -i .terraform/modules/k3s_cluster/modules/k3s-cluster/provision/ansible/ssh-private-key \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  ./slurm.yaml \
  almalinux@<K3S NODE IP>:~
```

Then log back into the k3s cluster VM. Escalate your privileges and copy the `slurm.yaml` file into `/root`.

```sh
# From the k3s cluster VM
sudo -i
cp /home/almalinux/slurm.yaml .
```

## Installing CRDs and Slurm operator with Helm

Now we are ready to use Helm to install some CRDs and the Slurm operator.

Run the following commands as the root user on the k3s cluster VM. In between, you can use `kubectl`, which we have aliased as `k`, to check on the deployments.

Install `cert-manager`:

```sh
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

Install `slurm-operator-crds`:

```sh
helm install slurm-operator-crds oci://ghcr.io/slinkyproject/charts/slurm-operator-crds
```

Install `slurm-operator`:

```sh
helm install slurm-operator oci://ghcr.io/slinkyproject/charts/slurm-operator \
  --namespace=slinky --create-namespace
```

Install `slurm`:

```sh
helm install slurm oci://ghcr.io/slinkyproject/charts/slurm \
  -f /root/slurm.yaml \
  --namespace=slurm --create-namespace
```

Use `kubectl` to monitor the deployments in the `slurm` and `slinky` namespaces. When they are complete, you may log out of the k3s cluster VM.

## Checking out Slurm

This minimal configuration has set up a Slurm cluster with one worker and a login service that can be accessed by SSH. You can run the following command from the root of the repository to access the Slurm cluster login service:

```sh
ssh -J condenser -i id_slurm -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@<SLURM LOGIN IP>
```

Where `id_slurm` is the private key file which is managed by Terraform, and `<SLURM LOGIN IP>` is the IP address that you provided in the module configuration. When passed to the `terraform-harvester-modules/k3s-cluster` module, it is assigned to an extra ingress service for Slurm.

After logging in you can run commands such as `sinfo`, `sacct`, and `srun hostname` to explore the Slurm cluster. The basic configuration provided in `slurm.yaml` enables all partitions and sets up a Slurm cluster with one worker. To learn more about the configuration options for the Helm chart values provided in `slurm.yaml`, check out the [Slinky installation guide](https://slinky.schedmd.com/slurm-operator/v1.2.0/installation.html).

If you want to observe the `slurm.conf` data, this is stored in a ConfigMap on the k3s cluster. You can take a look at the relevant resource using `k get configmap -A`. Check out the Slurm documentation to learn more about the [options configured in `slurm.conf`](https://slurm.schedmd.com/slurm.conf.html).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_id.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A dummy prefix. | `string` | `"my-test"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_random_val"></a> [random\_val](#output\_random\_val) | List your outputs here. |

---
<!-- END_TF_DOCS -->
