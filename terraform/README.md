# Terraform for Anthos clusters on AHV

---

## NOTE

The CentOS 8.2.2004 image used in this repo is EOL since December 31, 2021. The automation scripts in this repo use CentOS vault repo to download the packages (archived/unsupported packages)

---

## What to expect

In this folder you will find all the necessary to deploy an Anthos cluster on AHV with the additional functionalities for upgrading, scaling and decommissioning a cluster.

## Prerequisites

* Terraform:

  * 0.13.x or later
  * Nutanix provider 1.2.x or later

## Getting Started

1. Clone this repo

    ```terminal
    git clone https://github.com/nutanixdev/anthos-on-ahv.git
    ```

2. Change to terraform directory

    ```terminal
    cd anthos-on-ahv/terraform
    ```

3. Create `terraform.tfvars` to add the variable values

    ```terminal
    echo 'subnet_name = "<subnet_name>"
    anthos_version = "<anthos_version>"
    anthos_controlplane_vip = "<anthos_controlplane_vip>"
    anthos_ingress_vip = "<anthos_ingress_vip>"
    anthos_lb_addresspool = "<anthos_lb_addresspool>"
    anthos_cluster_name = "<anthos_cluster_name>"
    google_application_credentials_path = "<google_application_credentials_path>"
    amount_of_anthos_worker_vms = "<amount_of_anthos_worker_vms>"
    ntnx_pc_username = "<ntnx_pc_username>"
    ntnx_pc_password = "<ntnx_pc_password>"
    ntnx_pc_ip = "<ntnx_pc_ip>"
    ntnx_pe_storage_container = "<ntnx_pe_storage_container>"
    ntnx_pe_username = "<ntnx_pe_username>"
    ntnx_pe_password = "<ntnx_pe_password>"
    ntnx_pe_ip = "<ntnx_pe_ip>"
    ntnx_pe_dataservice_ip = "<ntnx_pe_dataservice_ip>"' > terraform.tfvars
    ```

4. Change file permissions due to credentials

    ```terminal
    chmod 0600 terraform.tfvars
    ```

5. Initialize Terraform

    ```terminal
    terraform init
    ```

6. Plan your Terraform deployment to check what actions will be performed

    ```terminal
    terraform plan
    ```

7. Launch the cluster deployment and confirm the message

    ```terminal
    terraform apply
    [...]
    yes
    ```

8. Once deployed, the cluster is registered in Anthos but GKE is not logged in until you use the token for the service account created in Kubernetes.

    * Retrieve the KUBECONFIG with the command available in the output and set the environment variable KUBECONFIG

        ```terminal
        scp -o "StrictHostKeyChecking no" -i <SSH key filename> <username>@<adminVm IP>:/home/<username>/baremetal/bmctl-workspace/<cluster name>/<cluster name>-kubeconfig .
        ```

        ```terminal
        export KUBECONFIG=<cluster name>-kubeconfig
        ```

    * Copy the token and use it in the GKE console (the service account name may vary depending if you changed the default value):

        ```terminal
        SECRET_NAME=$(kubectl get serviceaccount google-cloud-console -o jsonpath='{$.secrets[0].name}')
        kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode
        ```

## Day-2 Operations

* Scale Out/In: You can scale out/in your worker nodes pool

    1. Update *amount_of_anthos_worker_vms* in the `terraform.tfvars` with the new number of worker nodes

    2. Apply with Terraform to change the deployment and confirm

        ```terminal
        terraform apply
        [...]
        yes
        ```

* Upgrade Anthos: You can upgrade the Anthos cluster to newer versions. Be aware on supported vs unsupported versions

    1. Update *anthos_version* in the `terraform.tfvars` with the new Anthos cluster version

    2. Apply with Terraform to change the deployment and confirm

        ```terminal
        terraform apply
        [...]
        yes
        ```

* Decommissioning: When deleting an Anthos cluster, it will get cleaned up from Anthos portal as well

## Testing

It includes the Terraform's Testing Framework. You can easily make this part of your CI/CD pipelines and make sure this automation works as expected.

1. Move into the test directory

    ```terminal
    cd test
    ```

2. Make sure to have the `terraform.tfvars` file in the terraform folder

3. Run

    ```terminal
    go test -v -timeout 0  --run "TestTerraform_"
    ```