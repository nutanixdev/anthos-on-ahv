output "control_vm_ips" {
  value = local.control_vm_ips
}

output "admin_vm_ip" {
  value = local.admin_vm_ip
}

output "worker_vm_ips" {
  value = local.worker_vm_ips
}

output "scp_kubeconfig" {
  value = "Run following command on linux to retrieve the kubeconfig file:\n\n\t${local.kubeconfig_scp_command}\n"
}

output "token_export" {
  value = "Run following commands to retrieve the GKE/Anthos token:\n\n\t${local.anthos_token_command}\n"
}
