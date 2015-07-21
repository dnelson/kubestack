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
    default = "ami-0580426e"
}

variable "project" {}

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
