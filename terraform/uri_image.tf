resource "nutanix_image" "anthos_iso" {
  name        = "CentOS-8-Anthos"
  source_uri  = var.image_url
  description = "CentOS 8 image for Anthos uploaded via terraform"
  image_type  = "DISK_IMAGE"
}

