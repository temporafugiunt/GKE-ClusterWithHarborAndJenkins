variable "client_id" {}
variable "client_secret" {}

module "build-k8s-cluster" {
    source = "../CloudLibs/terraform/azure/build-k8s-cluster"
    client_id = "${var.client_id}"
    client_secret = "${var.client_secret}"
    cluster_name = "gcs-demo-prod"
    dns_prefix = "gcs-demo-prod"
    log_analytics_workspace_name = "gcs-demo-prod-law"
    cluster_location = "Central US"
    resource_group_name= "gcs-demo-prod-resgrp"
    agent_count = 2
    vm_size = "Standard_B2s"
    disk_size = 64
}

output "client_key" {
    value = "${module.build-k8s-cluster.client_key}"
}

output "client_certificate" {
    value = "${module.build-k8s-cluster.client_certificate}"
}

output "cluster_ca_certificate" {
    value = "${module.build-k8s-cluster.cluster_ca_certificate}"
}

output "cluster_username" {
    value = "${module.build-k8s-cluster.cluster_username}"
}

output "cluster_password" {
    value = "${module.build-k8s-cluster.cluster_password}"
}

output "kube_config" {
    value = "${module.build-k8s-cluster.kube_config}"
}

output "host" {
    value = "${module.build-k8s-cluster.host}"
}
