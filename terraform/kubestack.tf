output "kubernetes-api-server" {
    value = "https://${aws_instance.kube-apiserver.private_ip}:6443"
}

resource "template_file" "etcd" {
    filename = "etcd.env"
    vars {
        cluster_token = "${var.cluster_name}"
        discovery_url = "${var.discovery_url}"
    }
}

resource "template_file" "kubernetes_master" {
    filename = "kubernetes_master.env"
    vars {
        api_servers = "http://127.0.0.1:8080"
        etcd_servers = "${join(",", "${formatlist("http://%s:2379", aws_instance.etcd.*.private_ip)}")}"
        flannel_backend = "${var.flannel_backend}"
        flannel_network = "${var.flannel_network}"
        portal_net = "${var.portal_net}"
    }
}

resource "template_file" "kubernetes_worker" {
    filename = "kubernetes_worker.env"
    vars {
        api_servers = "http://${aws_instance.kube-apiserver.private_ip}:8080"
        etcd_servers = "${join(",", "${formatlist("http://%s:2379", aws_instance.etcd.*.private_ip)}")}"
        flannel_backend = "${var.flannel_backend}"
        flannel_network = "${var.flannel_network}"
        portal_net = "${var.portal_net}"
    }
}

provider "aws" {
    region = "${var.region}"
}

resource "aws_security_group" "kubernetes-api" {
    description = "Kubernetes API"
    name = "${var.cluster_name}-kubernetes-api"
    vpc_id = "${var.vpc_id}"
    tags {
        Name = "Kube SG"
    }

    ingress {
        protocol = "tcp"
        from_port = 6443
        to_port = 6443
        cidr_blocks = ["0.0.0.0/0"]

    }
    ingress {
        protocol = "tcp"
        from_port = 8080
        to_port = 8080
        cidr_blocks = ["0.0.0.0/0"]

    }
    ingress {
        protocol = "tcp"
        from_port = 2379
        to_port = 2380
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_instance" "etcd" {
    count = 3

    instance_type = "${var.machine_type}"
    availability_zone = "${lookup(var.zones, concat("zone", count.index))}"
    #TODO: replace with map for multi-region?
    ami = "${var.image}"
    vpc_security_group_ids = ["${aws_security_group.kubernetes-api.id}"]
    key_name = "${var.key_name}"
    subnet_id = "${lookup(var.subnets, lookup(var.zones, concat("zone", count.index)))}"
    tags {
        Name = "${var.cluster_name}-etcd${count.index}"
    }


    provisioner "remote-exec" {
        inline = [
            "cat <<'EOF' > /tmp/kubernetes.env\n${template_file.etcd.rendered}\nEOF",
            "echo 'ETCD_NAME=${var.cluster_name}-kube${count.index}' >> /tmp/kubernetes.env",
            "echo 'ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379' >> /tmp/kubernetes.env",
            "echo 'ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380' >> /tmp/kubernetes.env",
            "echo 'ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${self.private_ip}:2380' >> /tmp/kubernetes.env",
            "echo 'ETCD_ADVERTISE_CLIENT_URLS=http://${self.private_ip}:2379' >> /tmp/kubernetes.env",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo systemctl enable etcd",
            "sudo systemctl start etcd"
        ]
        connection {
            user = "core"
            agent = true
        }
    }

    depends_on = [
        "template_file.etcd",
    ]
}

resource "aws_instance" "kube-apiserver" {
    instance_type = "${var.machine_type}"
    availability_zone = "${var.zone}"
    ami = "${var.image}"
    vpc_security_group_ids = ["${aws_security_group.kubernetes-api.id}"]
    key_name = "${var.key_name}"
    subnet_id = "${var.subnet_id}"
    tags {
        Name = "${var.cluster_name}-kube-api${count.index}"
    }

    provisioner "file" {
        source = "${var.token_auth_file}"
        destination = "/tmp/tokens.csv"
        connection {
            user = "core"
            agent = true
        }
    }

    provisioner "remote-exec" {
        inline = [
            "sudo cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes_master.rendered}\nEOF",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo mkdir -p /etc/kubernetes",
            "sudo mv /tmp/tokens.csv /etc/kubernetes/tokens.csv",
            "sudo systemctl enable flannel",
            "sudo systemctl enable docker",
            "sudo systemctl enable kube-apiserver",
            "sudo systemctl enable kube-controller-manager",
            "sudo systemctl enable kube-scheduler",
            "sudo systemctl start flannel",
            "sudo systemctl start docker",
            "sudo systemctl start kube-apiserver",
            "sudo systemctl start kube-controller-manager",
            "sudo systemctl start kube-scheduler"
        ]
        connection {
            user = "core"
            agent = true
        }
    }

    depends_on = [
        "aws_instance.etcd",
        "template_file.kubernetes_master",
    ]
}

resource "aws_instance" "kube" {
    count = "${var.worker_count}"

    instance_type = "${var.machine_type}"
    availability_zone = "${lookup(var.zones, concat("zone", count.index))}"
    ami = "${var.image}"
    vpc_security_group_ids = ["${aws_security_group.kubernetes-api.id}"]
    key_name = "${var.key_name}"
    subnet_id = "${lookup(var.subnets, lookup(var.zones, concat("zone", count.index)))}"
    tags {
        Name = "${var.cluster_name}-kube-worker${count.index}"
    }


    provisioner "remote-exec" {
        inline = [
            "sudo cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes_worker.rendered}\nEOF",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo systemctl enable flannel",
            "sudo systemctl enable docker",
            "sudo systemctl enable kube-kubelet",
            "sudo systemctl enable kube-proxy",
            "sudo systemctl start flannel",
            "sudo systemctl start docker",
            "sudo systemctl start kube-kubelet",
            "sudo systemctl start kube-proxy"
        ]
        connection {
            user = "core"
            agent = true
        }
    }

    depends_on = [
        "aws_instance.kube-apiserver",
        "template_file.kubernetes_worker"
    ]
}
