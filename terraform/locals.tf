locals {
  ssh_key_default_name  = "anthos_${var.anthos_cluster_name}"
  cluster_uuid          = data.nutanix_subnet.vlan.cluster_uuid
  amount_of_control_vms = 3
  control_vm_ips        = nutanix_virtual_machine.control_vm.*.nic_list_status.0.ip_endpoint_list.0.ip
  worker_vm_ips         = nutanix_virtual_machine.worker_vm.*.nic_list_status.0.ip_endpoint_list.0.ip
  # worker_vm_ips                    = slice(nutanix_virtual_machine.worker_vm.*.nic_list_status.0.ip_endpoint_list.0.ip, 0, var.amount_of_anthos_worker_vms)
  admin_vm_ip                      = nutanix_virtual_machine.admin_vm.nic_list_status.0.ip_endpoint_list.0.ip
  google_project_id                = jsondecode(file(var.google_application_credentials_path)).project_id
  admin_vm_google_credentials_path = "/home/${var.admin_vm_username}/google_application_credentials"
  kubeconfig_path                  = "/home/${var.admin_vm_username}/baremetal/bmctl-workspace/${var.anthos_cluster_name}/${var.anthos_cluster_name}-kubeconfig"
  kubeconfig_scp_command           = "scp -o \"StrictHostKeyChecking no\" -i ${local_file.anthos_private_ssh_key.filename} ${var.admin_vm_username}@${local.admin_vm_ip}:${local.kubeconfig_path} ."
  anthos_token_command             = "SECRET_NAME=$(kubectl get serviceaccount google-cloud-console -o jsonpath='{$.secrets[0].name}')\n\tkubectl get secret $${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode"
  scripts_path                     = "../scripts"
}

