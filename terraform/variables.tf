variable anthos_version {
  type        = string
  description = "Anthos cluster version"
  default     = "1.6.1"
}
variable anthos_cluster_name {
  type        = string
  description = "Anthos cluster name"
}

variable anthos_controlplane_vip {
  type        = string
  description = "This is the IP address for Kubernetes API. Format: XXX.XXX.XXX.XXX"
  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.anthos_controlplane_vip))
    error_message = "Invalid IP format. Expected: XXX.XXX.XXX.XXX."
  }
}

variable anthos_pods_network {
  type        = string
  default     = "172.30.0.0/16"
  description = "This is the network for your pods. Preferably do not overlap with other networks. CIDR format: XXX.XXX.XXX.XXX/XX"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", var.anthos_pods_network))
    error_message = "Invalid CIDR format for variable anthos_pods_network. Expected: XXX.XXX.XXX.XXX/XX."
  }
}

variable anthos_services_network {
  type        = string
  default     = "172.31.0.0/16"
  description = "This is the network for your services. Preferably do not overlap with other networks. CIDR format: XXX.XXX.XXX.XXX/XX"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", var.anthos_services_network))
    error_message = "Invalid CIDR format for variable anthos_services_network. Expected: XXX.XXX.XXX.XXX/XX."
  }
}

variable anthos_ingress_vip {
  type        = string
  description = "This is the IP address for Kubernetes Ingress. This address MUST be within the load balancing pool. Format: XXX.XXX.XXX.XXX"
  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.anthos_ingress_vip))
    error_message = "Invalid IP format for variable anthos_ingress_vip. Expected: XXX.XXX.XXX.XXX/XX."
  }
}

variable anthos_lb_addresspool {
  type        = string
  description = "This is the IP address range for Load Balancing. Format: XXX.XXX.XXX.XXX-YYY.YYY.YYY.YYY"
}

variable kubernetes_service_account {
  type        = string
  default     = "google-cloud-console"
  description = "This K8s SA is for Google Cloud Console so the K8s cluster can be managed in GKE. This service account will have cluster-admin role for Google Cloud Marketplace to work. Default: google-cloud-console"
}

variable python_anthos_genconfig {
  type        = string
  default     = "https://raw.githubusercontent.com/pipoe2h/calm-dsl/anthos-on-ahv/blueprints/anthos-on-ahv/scripts/anthos_generate_config.py"
  description = "This script is hosted externally and produce an Anthos configuration file for cluster creation with user provided inputs during launch. DO NOT CHANGE default value unless you will host the script in an internal repository"
}

variable ntnx_csi_url {
  type        = string
  default     = "http://download.nutanix.com/csi/v2.3.1/csi-v2.3.1.tar.gz"
  description = "Nutanix CSI Driver URL. Minimum supported version is 2.3.1"
}

variable ntnx_pe_ip {
  type        = string
  description = "Prism Element IP address. Required for CSI installation"
}

variable ntnx_pe_port {
  type        = number
  default     = 9440
  description = "Prism Element port"
}

variable ntnx_pe_dataservice_ip {
  type        = string
  description = "Prism Element dataservices IP address. Required for CSI installation"
}

variable ntnx_pe_storage_container {
  type        = string
  description = "This is the Nutanix Storage Container where the requested Persistent Volume Claims will get their volumes created. You can enable things like compression and deduplication in a Storage Container. The recommendation is to create at least one storage container in Prism Element well identified for Kubernetes usage. This will facilitate the search of persistent volumes when the environment scales."
}

variable ntnx_pe_username {
  type        = string
  description = "Prism Element username. Required for CSI installation"
}

variable ntnx_pe_password {
  type        = string
  description = "Prism Element password. Required for CSI installation"
}

variable google_application_credentials_path {
  type        = string
  description = "local path to the GKE credential json."
}

variable subnet_name {
  type        = string
  description = "Subnet used for Anthos deployment."
}

variable image_url {
  type        = string
  default     = "https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2"
  description = "CentOS image URL required to deploy Anthos"
}

variable amount_of_anthos_worker_vms {
  type        = number
  default     = 2
  description = "Amount of Anthos worker VMs. Changing this value will result in scale-up or scale-down of the cluster"
  validation {
    condition     = var.amount_of_anthos_worker_vms > 0
    error_message = "Minimum 1 worker node is required."
  }
}

variable admin_vm_username {
  type        = string
  description = "Username used for Anthos installation. Default: nutanix"
  default     = "nutanix"
}

variable anthos_worker_vm_config {
  description = "Configuration of the Anthos worker VMs. Note: The minimum OS disk size MUST be 128GB, recommended by Google is 256GB"
  type = object({
    num_sockets          = number
    memory_size_mib      = number
    num_vcpus_per_socket = number
    disk_size_mib        = number
    }
  )
  default = {
    num_sockets          = 4
    memory_size_mib      = 32 * 1024
    disk_size_mib        = 131072
    num_vcpus_per_socket = 1
  }
}

variable anthos_control_vm_config {
  description = "Configuration of the Anthos control VMs. Note: The minimum OS disk size MUST be 128GB, recommended by Google is 256GB"
  type = object({
    num_sockets          = number
    memory_size_mib      = number
    num_vcpus_per_socket = number
    disk_size_mib        = number
    }
  )
  default = {
    num_sockets          = 4
    memory_size_mib      = 32 * 1024
    disk_size_mib        = 131072
    num_vcpus_per_socket = 1
  }
}

variable anthos_admin_vm_config {
  description = "Configuration of the Anthos admin VM."
  type = object({
    num_sockets          = number
    memory_size_mib      = number
    num_vcpus_per_socket = number
    disk_size_mib        = number
    }
  )
  default = {
    num_sockets          = 4
    memory_size_mib      = 32 * 1024
    disk_size_mib        = 131072
    num_vcpus_per_socket = 1
  }
}

