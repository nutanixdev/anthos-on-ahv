resource "null_resource" "write_variable_file" {
  depends_on = [
    nutanix_virtual_machine.worker_vm,
    nutanix_virtual_machine.control_vm,
    nutanix_virtual_machine.admin_vm
  ]
  triggers = {
    worker_vm_ips  = join(",", local.worker_vm_ips),
    anthos_version = var.anthos_version
  }
  connection {
    user        = var.admin_vm_username
    private_key = file(local_file.anthos_private_ssh_key.filename)
    host        = nutanix_virtual_machine.admin_vm.nic_list_status[0].ip_endpoint_list[0].ip
  }
  provisioner "file" {
    destination = "~/variables.sh"
    content = templatefile("${path.module}/templates/variables.sh.tpl", {
      environment_variables = {
        "GOOGLE_APPLICATION_CREDENTIALS" : local.admin_vm_google_credentials_path,
        "ANTHOS_TEMPLATE_PATH" : "/home/${var.admin_vm_username}/baremetal/bmctl-workspace/${var.anthos_cluster_name}/${var.anthos_cluster_name}.yaml ",
        "ANTHOS_SSH_KEY" : "/home/${var.admin_vm_username}/.ssh/id_rsa",
        "ANTHOS_CLUSTER_TYPE" : "hybrid",
        "ANTHOS_CONTROLPLANE_ADDRESSES" : join(",", local.control_vm_ips),
        "ANTHOS_LVPNODEMOUNTS" : "/home/${var.admin_vm_username}/localpv-disk",
        "ANTHOS_LVPSHARE" : "/home/${var.admin_vm_username}/localpv-share",
        "ANTHOS_LOGINUSER" : var.admin_vm_username,
        "ANTHOS_WORKERNODES_ADDRESSES" : join(",", local.worker_vm_ips),
        "ANTHOS_CLUSTER_NAME" : var.anthos_cluster_name,
        "ANTHOS_CONTROLPLANE_VIP" : "\"${var.anthos_controlplane_vip}\"",
        "ANTHOS_PODS_NETWORK" : var.anthos_pods_network,
        "ANTHOS_SERVICES_NETWORK" : var.anthos_services_network,
        "ANTHOS_INGRESS_VIP" : var.anthos_ingress_vip,
        "ANTHOS_LB_ADDRESSPOOL" : var.anthos_lb_addresspool,
        "ANTHOS_VERSION" : var.anthos_version,
        "PYTHON_ANTHOS_GENCONFIG" : var.python_anthos_genconfig,
        "KSA_NAME" : var.kubernetes_service_account,
        "NTNX_CSI_URL" : var.ntnx_csi_url,
        "NTNX_PE_IP" : var.ntnx_pe_ip,
        "NTNX_PE_PORT" : var.ntnx_pe_port,
        "NTNX_PE_USERNAME" : var.ntnx_pe_username,
        "NTNX_PE_PASSWORD" : var.ntnx_pe_password,
        "NTNX_PE_DATASERVICE_IP" : var.ntnx_pe_dataservice_ip,
        "NTNX_PE_STORAGE_CONTAINER" : var.ntnx_pe_storage_container,
        "KUBECONFIG" : local.kubeconfig_path,
        "GOOGLE_PROJECT_ID" : local.google_project_id
      }
    })
  }
}

resource "null_resource" "configure_admin_vm" {
  depends_on = [
    null_resource.write_variable_file
  ]
  triggers = {
    scripts_path     = local.scripts_path
    admin_vm_user    = [for x in nutanix_virtual_machine.admin_vm.categories : x.value if can(regex("LOGIN_USER", x.name))][0]
    private_key_path = [for x in nutanix_virtual_machine.admin_vm.categories : x.value if can(regex("SSH_KEY", x.name))][0]
    admin_vm_ip      = nutanix_virtual_machine.admin_vm.nic_list_status[0].ip_endpoint_list[0].ip
  }
  connection {
    user        = self.triggers.admin_vm_user
    private_key = file(self.triggers.private_key_path)
    host        = self.triggers.admin_vm_ip
  }
  provisioner "file" {
    content     = file(var.google_application_credentials_path)
    destination = local.admin_vm_google_credentials_path
  }
  provisioner "file" {
    content     = file(local_file.anthos_private_ssh_key.filename)
    destination = "~/.ssh/id_rsa"
  }
  provisioner "file" {
    source      = "${local.scripts_path}/anthos_unregister_node.sh"
    destination = "~/anthos_unregister_node.sh"
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/centos_install_docker.sh"
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/gcloud_install_sdk.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '======Activating Service Account======'",
      "gcloud auth activate-service-account --key-file=${local.admin_vm_google_credentials_path}",
    ]
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/anthos_install_bmctl.sh"
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/anthos_create_cluster.sh"
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/gke_configure_cloudconsole.sh"
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/ntnxk8s_install_csi.sh"
  }
  provisioner "remote-exec" {
    when   = destroy
    script = "${self.triggers.scripts_path}/anthos_reset_cluster.sh"
  }
}
resource "null_resource" "scale_nodes" {
  depends_on = [
    null_resource.configure_admin_vm,
    null_resource.write_variable_file
  ]
  triggers = {
    worker_vm_ips = join(",", local.worker_vm_ips),
  }
  connection {
    user        = var.admin_vm_username
    private_key = file(local_file.anthos_private_ssh_key.filename)
    host        = nutanix_virtual_machine.admin_vm.nic_list_status[0].ip_endpoint_list[0].ip
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/anthos_scale_cluster.sh"
  }
}

resource "null_resource" "upgrade_cluster" {
  depends_on = [
    null_resource.configure_admin_vm,
    null_resource.write_variable_file
  ]
  triggers = {
    anthos_version = var.anthos_version,
  }
  connection {
    user        = var.admin_vm_username
    private_key = file(local_file.anthos_private_ssh_key.filename)
    host        = nutanix_virtual_machine.admin_vm.nic_list_status[0].ip_endpoint_list[0].ip
  }
  provisioner "remote-exec" {
    script = "${local.scripts_path}/anthos_upgrade_cluster.sh"
  }
}
