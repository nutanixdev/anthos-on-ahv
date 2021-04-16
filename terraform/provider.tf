provider "nutanix" {
  endpoint = var.ntnx_pc_ip
  username = var.ntnx_pc_username
  password = var.ntnx_pc_password
  wait_timeout = 4
  insecure     = true
  port         = 9440
}
