# Anthos clusters on AHV

## What to expect

This repo provides two automation methods for deploying Anthos clusters on AHV. You can choose between a Calm blueprint or a Terraform file.

## Overview

The characteristics for the Kubernetes cluster are:

* Anthos model: [bare metal](https://cloud.google.com/anthos/clusters/docs/bare-metal/1.6/concepts/about-bare-metal)

* Anthos versions:

  * Supported: [1.6.x](https://cloud.google.com/anthos/docs/resources/partner-platforms#nutanix)

  * Unsupported: 1.7.0

* Type: hybrid - <https://cloud.google.com/anthos/clusters/docs/bare-metal/1.6/installing/install-prep#hybrid_cluster_deployment>

* Number of virtual machines: 6 (Total resources: 24 vCPU / 192 GB memory / 768 GB storage )

  * 1 x Admin workstation

  * 3 x Control plane

  * 2 x Worker nodes

* Virtual machine OS: CentOS 8.2 GenericCloud - <https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2>

* High availability: yes

* Load balancing: yes ([bundled](https://cloud.google.com/anthos/clusters/docs/bare-metal/1.6/installing/load-balance))

* Ingress: yes

* Persistent storage: yes (Nutanix CSI)

* Proxy: no

* KubeVirt: no

* OpenID Connect: no

* Application logs/metrics: no

* Scale Out/In: yes

* Upgrade Anthos version: yes

* Decommission Anthos cluster: yes

## Prerequisites

* Nutanix:

  * Cluster:

    * AHV: 20201105.1045 or later

    * AOS: 5.19.1 or later

    * iSCSI data service IP configured

    * VLAN network with AHV IPAM configured

    * Prism Central: 2020.11.0.1 or later

* Google Cloud:

  * A project with Owner role

  * The project must have enabled Monitoring - <https://console.cloud.google.com/monitoring>

  * A service account - <https://console.cloud.google.com/iam-admin/serviceaccounts/create>

    * Role: Project Owner

    * A private key: JSON

* Networking:

  * Internet connectivity

  * AHV IPAM: Minimum 6 IP addresses available for the virtual machines

  * Kubernetes:

    * Control plane VIP: One IP address in the same network than virtual machines but not part of the AHV IPAM

    * Ingress VIP: One IP address in the same network than virtual machines but not part of the AHV IPAM. This IP must be part of the load balancing pool

    * Load balancing pool: Range of IP addresses in the same network than virtual machines but not part of the AHV IPAM. The Ingress VIP is included in this pool

    * Pods network: CIDR network with enough IP addresses, usually /16 and not sharing the same network than virtual machines or Kubernetes Services. If your containerized application must communicate with a system out of the Kubernetes cluster, make sure then this network doesn't overlap either with the external system network

    * Services network: CIDR network with enough IP addresses, usually /16 and not sharing the same network than virtual machines or Kubernetes Pods. If your containerized application must communicate with a system out of the Kubernetes cluster, make sure then this network doesn't overlap either with the external system network

* Credentials:

  * (Calm only) Operating system: you need a SSH key. It must start with `---BEGIN RSA PRIVATE KEY---`. To generate one in a terminal:

    ```console
    ssh-keygen -m PEM -t rsa -f <keyname>
    ```

  * Prism Element: an account, local or Active Directory, with *User Admin* role. This is for the CSI plugin configuration

## Variables

| Calm | Terraform | Description |
| --- | --- | --- |
| NTNX_PC_IP | n/a | If you are using a remote Prism Central instance, use the IP address of that instance. This is used to expand the OS disk via PC API |
| OS_DISK_SIZE | *_vm_config | The minimum OS disk size MUST be 128GB, recommended by Google is 256GB |
| NTNX_CSI_URL | ntnx_csi_url | Nutanix CSI Driver URL. Minimum supported version is 2.3.1 |
| NTNX_PE_IP | ntnx_pe_ip | The Prism Element VIP address is needed for the CSI plugin to create persistent volumes via the API. This VIP doesn't have to be the one where the Anthos cluster will run. You can choose any VIP of any of your clusters from where you want to get persistent storage |
| NTNX_PE_PORT | ntnx_pe_port | Prism Element port. Default is *9440* |
| NTNX_PE_DATASERVICE_IP | ntnx_pe_dataservice_ip | Data service is required to allow iSCSI connectivity between the Kubernetes pods and the volumes created by CSI plugin |
| NTNX_PE_STORAGE_CONTAINER | ntnx_pe_storage_container | This is the Nutanix Storage Container where the requested Persistent Volume Claims will get their volumes created. You can enable things like compression and deduplication in a Storage Container. The recommendation is to create at least one storage container in Prism Element well identified for Kubernetes usage. This will facilitate the search of persistent volumes when the environment scales |
| ANTHOS_CLUSTER_NAME | anthos_cluster_name | Anthos cluster name |
| ANTHOS_VERSION | anthos_version | Anthos cluster version. Supported: 1.6.x (default 1.6.2) - Unsupported: 1.7.0 |
| ANTHOS_SERVICES_NETWORK | anthos_services_network | This is the network for your services. Preferably do not overlap with other networks. CIDR format: XXX.XXX.XXX.XXX/XX |
| ANTHOS_PODS_NETWORK | anthos_pods_network | This is the network for your pods. Preferably do not overlap with other networks. CIDR format: XXX.XXX.XXX.XXX/XX | 
| ANTHOS_CONTROLPLANE_VIP | anthos_controlplane_vip | This is the IP address for Kubernetes API. Format: XXX.XXX.XXX.XXX |
| ANTHOS_INGRESS_VIP | anthos_ingress_vip | This is the IP address for Kubernetes Ingress. This address MUST be within the load balancing pool. Format: XXX.XXX.XXX.XXX |
| ANTHOS_LB_ADDRESSPOOL | anthos_lb_addresspool | This is the IP address range for Load Balancing. Format: XXX.XXX.XXX.XXX-YYY.YYY.YYY.YYY |
| KUBERNETES_SERVICE_ACCOUNT | kubernetes_service_account | This K8s SA is for Google Cloud Console so the K8s cluster can be managed in GKE. This service account will have cluster-admin role for Google Cloud Marketplace to work. Default is  *google-cloud-console* |
| PYTHON_ANTHOS_GENCONFIG | python_anthos_genconfig | This script is hosted externally and produce an Anthos configuration file for cluster creation with user provided inputs during launch. DO NOT CHANGE default value unless you will host the script in an internal repository |
| (credential) | ntnx_pe_username | Username for Prism Element cluster for the CSI plug-in to work |
| (credential) | ntnx_pe_password | Password for Prism Element cluster |
| (credential) | google_application_credentials_path | Local path to the GCP service account key in JSON format |
| (service spec) | subnet_name | Subnet used for Anthos deployment |
| (service replica count) | amount_of_anthos_worker_vms | Amount of Anthos worker VMs. Changing this value will result in scale-up or scale-down of the cluster |
| (credential) | admin_vm_username | Username used for Anthos installation. Default: nutanix |
