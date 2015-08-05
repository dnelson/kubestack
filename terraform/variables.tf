variable "account_file" {
    default = "/etc/kubestack-account.json"
}

variable "discovery_url" {}

variable "flannel_backend" {
    default = "vxlan"
}

variable "flannel_network" {
    default = "10.10.0.0/16"
}

variable "image" {
    default = "ami-2538e54e"
}

variable "portal_net" {
    default = "10.200.0.0/16"
}

variable "region" {
    default = "us-east"
}

variable "key_name" {}

variable "token_auth_file" {
    default = "secrets/tokens.csv"
}

variable "worker_count" {
    default = 3
}

variable "zones" {
    default = {
        zone0 = "us-east-1a"
        zone1 = "us-east-1b"
        zone2 = "us-east-1c"
    }
}

variable "subnets" {
    default = {
/* # private
        us-east-1a = "subnet-e08022cb"
        us-east-1b = "subnet-7f1d8408"
        us-east-1c = "subnet-58dc5901"
*/
        us-east-1a = "subnet-9313b4b8"
        us-east-1b = "subnet-7f1d8408"
        us-east-1c = "subnet-5fda6306"
    }
}

variable "zone" {
    default = "us-east-1a"
}

variable "cluster_name" {
    default = "testing"
}

variable "machine_type" {
    default = "t2.micro"
}

variable "subnet_id" {
    default = ""
}

variable "vpc_id" {
    default = ""
}
