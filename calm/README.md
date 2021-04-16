# Calm blueprint for Anthos clusters on AHV

## What to expect

With this folder you can generate a Calm blueprint using DSL or just upload a compiled blueprint in JSON format directly into Calm.

## Prerequisites

* Calm:

  * 3.0.0.2 or later 
  * A project with AHV account

## Getting Started

This blueprint has been developed using Calm DSL to provide Infrastructure as Code. If you are not familiar with DSL, you can learn with this [post series](https://www.nutanix.dev/calm-dsl). There is no need for you to use DSL, you can just upload the JSON file linked in the following section.

If you want to compile this blueprint using Calm DSL move to [Using DSL](#using-dsl), otherwise, continue reading to use the blueprint option.

## Using Blueprint

This method is for using the *blueprint.json* file available in the [Calm community repo](https://github.com/nutanix/blueprints)

1. Save the [blueprint](https://raw.githubusercontent.com/nutanix/blueprints/master/anthos-on-ahv/blueprint.json) in your computer. You can right-click the link, and choose *Save Link As...*

2. Upload the blueprint into Calm

3. Select the same network in the *Config Pane* for each of the three services: adminVm, ControlPlaneVMs and WorkerNodesVMs

4. Credentials:

    * CRED_OS: Upload a SSH private key. You can leave the user *nutanix* if you like

    * CRED_PE: Configure username and password with a user that has *User Admin* role in the Prism Element cluster that will provide persistent storage

    * CRED_PC: Configure username and password with a user that has *Create/Update VM* role in the Prism Central instance responsible for the virtual machines. This is required to expand the virtual disk via API

    * CRED_GCLOUD: This is the GCP Service Account name you have created with the format *`name`*@*`project`*.iam.gserviceaccount.com. Upload the JSON key that was generated as part of the GCP service account creation

5. Default Application Profile variables

    Configure the [launch variables](#variables) values accordingly to your environment. There are a few of them that are privates, runtime disabled, that most of the time are static and doesn't need changes. You can always make them available at launch checking the runtime icon if you need to deliver more flexibility to the user.

6. Save the blueprint and launch. The complete deployment process takes about an hour.

7. Once deployed, the cluster is registered in Anthos but GKE is not logged in until you use the token for the service account created in Kubernetes. SSH into the *Admin virtual machine* and run the following commands (you will need to grab the KUBECONFIG from the admin virtual machine). Copy the token and use it in the GKE console (the service account name may vary depending if you changed the default value):

    ```terminal
    SECRET_NAME=$(kubectl get serviceaccount google-cloud-console -o jsonpath='{$.secrets[0].name}')
    kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode
    ```

## Using DSL

Make sure your DSL is initialized beforehand, if you need help with this refer to this [post series](https://www.nutanix.dev/calm-dsl)

1. Clone this repo

    ```terminal
    git clone https://github.com/nutanixdev/anthos-on-ahv.git
    ```

2. Move to blueprint directory

    ```terminal
    cd calm-dsl/blueprints/anthos-on-ahv
    ```

3. Create the required credentials

    ```terminal
    mkdir -p .local/secrets

    # GCP Service Account
    echo "name@project..iam.gserviceaccount.com" > .local/secrets/gcloud_account
    echo """{
        JSON payload
    }""" > .local/secrets/gcloud_key

    # Linux OS username and SSH private key
    echo "nutanix" > .local/secrets/os_username
    echo """---BEGIN RSA PRIVATE KEY---
        KEY payload
    ---""" > .local/secrets/os_key

    # Prism Element credential with User Admin role
    echo "service_account" > .local/secrets/pe_username
    echo "password" > .local/secrets/pe_password

    # Prism Central credential with Create/Update VM role
    echo "service_account" > .local/secrets/pc_username
    echo "password" > .local/secrets/pc_password
    ```

4. (Optional) Update default values for [launch variables](##variables). You can find the variables in *class Default(Profile):* section

    ```terminal
    vi blueprint.py
    ```

5. Create blueprint

    ```terminal
    calm create bp blueprint.py
    ```

6. Launch it. The complete deployment process takes about an hour.

    ```terminal
    calm create app -f blueprint.py
    ```

7. Once deployed, the cluster is registered in Anthos but GKE is not logged in until you use the token for the service account created in Kubernetes. From your computer terminal run the following commands copying the token and using it in the GKE console (the service account name may vary depending if you changed the default value):

    ```terminal
    SECRET_NAME=$(kubectl get serviceaccount google-cloud-console -o jsonpath='{$.secrets[0].name}')
    kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode
    ```

## Day-2 Operations

* Scale Out/In: You can scale out/in your worker nodes pool

* Upgrade Anthos: You can upgrade the Anthos cluster to newer versions. Be aware on supported vs unsupported versions

* Decommissioning: When deleting an Anthos cluster, it will get cleaned up from Anthos portal as well
