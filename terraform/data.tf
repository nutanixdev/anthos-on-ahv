data "nutanix_subnet" "vlan" {
  subnet_name = var.subnet_name
}

data nutanix_cluster "cluster" {
  cluster_id = local.cluster_uuid
}
