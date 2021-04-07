resource "null_resource" "retrieve_kube_config" {
  depends_on = [null_resource.configure_admin_vm]
  triggers = {
    "local_kubeconfig_path" = local.kubeconfig_path
  }
  provisioner "local-exec" {
    command = local.kubeconfig_scp_command
  }
}
