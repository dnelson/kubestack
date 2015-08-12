# Kubestack

Provision a Kubernetes cluster with [Packer](https://packer.io) and [Terraform](https://www.terraform.io) on Amazon Web Services.

## Status

Ready for testing. Over the next couple of weeks the repo should be generic enough for reuse with complete documentation.

## Prep

- [Install Packer](https://packer.io/docs/installation.html)
- [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)

The Packer and Terraform configs assume your authentication JSON file is stored under `/etc/kubestack-account.json`

## Packer Images

Immutable infrastructure is the future. Instead of using cloud-init to provision machines at boot we'll create a custom image using Packer.

Run the packer commands below will create the following image:

```
kubestack-0-17-1-v20150606
```

### Create the Kubestack Base Image

```
cd packer
packer build -var-file=settings.json kubestack.json
```

## Terraform

Terraform will be used to declare and provision a Kubernetes cluster.

### Prep

Generate an [etcd discovery](https://coreos.com/docs/cluster-management/setup/cluster-discovery/) token:

```
curl https://discovery.etcd.io/new?size=3
https://discovery.etcd.io/465df9c06a9d589...
```

Edit `terraform/terraform.tfvars`. Add the required values:

```
discovery_url = "https://discovery.etcd.io/465df9c06a9d589..."
project = "kubestack"
sshkey_metadata = "core: ssh-rsa AAAAB3NzaC1yc2EA..."
```

- Add API tokens to `terraform/secrets/tokens.csv`. See [Kubernetes Authentication Plugins](https://github.com/GoogleCloudPlatform/kubernetes/blob/release-1.0/docs/authentication.md) for more details.

Example tokens.csv

```
04b6d6bfe5bexample82db624, kelseyhightower, kelseyhightower
```

- Ensure your local ssh-agent is running and your ssh key has been added. This step is required by the terraform provisioner.

```
ssh-add ~/.ssh/id_rsa
```


### Provision the Kubernetes Cluster

```
cd terraform
terraform plan
terraform apply
```

```
terraform destroy
```

### Resize the number of worker nodes

Edit `terraform/terraform.tfvars`. Set `worker_count` to the desired value:

```
worker_count = 3
```

Apply the changes:

```
terraform plan
terraform apply
```

```
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate

Outputs:

  kubernetes-api-server = https://203.0.113.158:6443
```

## Next Steps

### Configure kubectl

Replace `$kubernetes-api-server` with the terraform output.
Replace `$token` and `$user` with the info from `terraform/secrets/tokens.csv`.

```
kubectl config set-cluster kubestack --insecure-skip-tls-verify=true --server=$kubernetes-api-server
kubectl config set-credentials kelseyhightower --token='$token'
kubectl config set-context kubestack --cluster=kubestack --user=$user
kubectl config use-context kubestack
```

```
kubectl config view
```

```
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $kubernetes-api-server
  name: kubestack
contexts:
- context:
    cluster: kubestack
    user: $user
  name: kubestack
current-context: kubestack
kind: Config
preferences: {}
users:
- name: $user
  user:
    token: $token
```

## Register the worker nodes

Nodes will be named based on the following convention:

```
${cluster_name}-kube${count}.c.${project}.internal
```

Edit `testing-kube0.c.kubestack.internal.json`

```
{
  "kind": "Node",
  "apiVersion": "v1beta3",
  "metadata": {
    "name": "testing-kube0.c.kubestack.internal"
  },
  "spec": {
    "externalID": "testing-kube0.c.kubestack.internal"
  }
}
```

```
kubectl create -f testing-kube0.c.kubestack.internal.json
```
