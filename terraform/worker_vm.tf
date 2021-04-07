data "template_file" "worker_vm_cloud-init" {
  count    = var.amount_of_anthos_worker_vms
  template = file("${path.module}/templates/cloud-init.tpl")
  vars = {
    hostname            = "${var.anthos_cluster_name}-anthos-workerVm-${count.index}"
    admin_vm_username   = var.admin_vm_username
    admin_vm_public_key = tls_private_key.anthos_ssh_key.public_key_openssh
  }
}
resource "nutanix_virtual_machine" "worker_vm" {
  count                = var.amount_of_anthos_worker_vms
  name                 = "${var.anthos_cluster_name}-anthos-workerVm-${count.index}"
  cluster_uuid         = local.cluster_uuid
  num_vcpus_per_socket = var.anthos_worker_vm_config.num_vcpus_per_socket
  num_sockets          = var.anthos_worker_vm_config.num_sockets
  memory_size_mib      = var.anthos_worker_vm_config.memory_size_mib
  disk_list {
    data_source_reference = {
      kind = "image"
      uuid = nutanix_image.anthos_iso.id
    }
    device_properties {
      device_type = "DISK"
      disk_address = {
        device_index = 0
        adapter_type = "SCSI"
      }
    }
    disk_size_bytes = var.anthos_worker_vm_config.disk_size_mib * 1024 * 1024
  }
  guest_customization_cloud_init_user_data = base64encode(data.template_file.worker_vm_cloud-init[count.index].rendered)

  nic_list {
    subnet_uuid = data.nutanix_subnet.vlan.id
  }
  categories {
    name  = nutanix_category_key.anthos_cluster_name.id
    value = nutanix_category_value.anthos_cluster_name.id
  }
  categories {
    name  = nutanix_category_key.anthos_login_user.id
    value = nutanix_category_value.anthos_login_user.id
  }
  categories {
    name  = nutanix_category_key.anthos_ssh_key.id
    value = nutanix_category_value.anthos_ssh_key.id
  }
  categories {
    name  = nutanix_category_key.anthos_node_type.id
    value = nutanix_category_value.anthos_node_type_worker.id
  }
  categories {
    name  = nutanix_category_key.anthos_admin_vm_ip.id
    value = nutanix_category_value.anthos_admin_vm_ip.id
  }
  connection {
    user        = [for x in self.categories : x.value if can(regex("LOGIN_USER", x.name))][0]
    private_key = file([for x in self.categories : x.value if can(regex("SSH_KEY", x.name))][0])
    host        = self.nic_list_status[0].ip_endpoint_list[0].ip
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/centos_install_docker.sh"
  }
  provisioner "remote-exec" {
    connection {
      user        = [for x in self.categories : x.value if can(regex("LOGIN_USER", x.name))][0]
      private_key = file([for x in self.categories : x.value if can(regex("SSH_KEY", x.name))][0])
      host        = [for x in self.categories : x.value if can(regex("ADMIN_VM_IP", x.name))][0]
    }
    when = destroy
    inline = [
      "sh ~/anthos_unregister_node.sh ${self.nic_list_status[0].ip_endpoint_list[0].ip}",
    ]
  }
}
