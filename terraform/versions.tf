terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    nutanix = {
      source = "terraform-providers/nutanix"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.13"
}
