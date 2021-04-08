import os
import json

from calm.dsl.builtins import Service, Package, Substrate
from calm.dsl.builtins import Deployment, Profile, Blueprint
from calm.dsl.builtins import action, ref, basic_cred, CalmTask
from calm.dsl.builtins import read_local_file, read_ahv_spec, read_vmw_spec, read_file
from calm.dsl.builtins import vm_disk_package
from calm.dsl.builtins import CalmVariable as Variable
from calm.dsl.builtins import read_env

# Script paths
SHARED_SCRIPTS_PATH = "../scripts"
LOCAL_SCRIPTS_PATH = "local_scripts"

# Credentials definition
OS_USERNAME = os.getenv("CALMDSL_OS_USERNAME") or read_local_file(
    os.path.join("secrets", "os_username")
)
OS_KEY = os.getenv("CALMDSL_OS_KEY") or read_local_file(
    os.path.join("secrets", "os_key")
)
CRED_OS = basic_cred(OS_USERNAME, OS_KEY, name="CRED_OS", type="KEY", default=True,)

PC_USERNAME = os.getenv("CALMDSL_PC_USERNAME") or read_local_file(
    os.path.join("secrets", "pc_username")
)
PC_PASSWORD = os.getenv("CALMDSL_PC_PASSWORD") or read_local_file(
    os.path.join("secrets", "pc_password")
)
CRED_PC = basic_cred(
    PC_USERNAME, PC_PASSWORD, name="CRED_PC", type="PASSWORD", default=False,
)

PE_USERNAME = os.getenv("CALMDSL_PE_USERNAME") or read_local_file(
    os.path.join("secrets", "pe_username")
)
PE_PASSWORD = os.getenv("CALMDSL_PE_PASSWORD") or read_local_file(
    os.path.join("secrets", "pe_password")
)
CRED_PE = basic_cred(
    PE_USERNAME, PE_PASSWORD, name="CRED_PE", type="PASSWORD", default=False,
)

GCLOUD_ACCOUNT = os.getenv("CALMDSL_GCLOUD_ACCOUNT") or read_local_file(
    os.path.join("secrets", "gcloud_account")
)
GCLOUD_KEY = os.getenv("CALMDSL_GCLOUD_KEY") or read_local_file(
    os.path.join("secrets", "gcloud_key")
)
CRED_GCLOUD = basic_cred(
    GCLOUD_ACCOUNT, GCLOUD_KEY, name="CRED_GCLOUD", type="KEY", default=False,
)

# Downloadable image for AHV
AHV_CENTOS = vm_disk_package(
    name="AHV_CENTOS", config_file="specs/image/centos-cloudimage.yaml"
)

# Anthos Control VMs Service
class ControlPlaneVMs(Service):

    """Control Plane VMs"""

    @action
    def Centos_Install_Docker():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/centos_install_docker.sh",
            name="Install_Docker",
        )

    @action
    def NTNXPC_Extend_Disk():
        CalmTask.Exec.escript(
            filename=LOCAL_SCRIPTS_PATH + "/ntnxpc_extend_disk.py",
            name="Extend_OS_Disk",
        )


class ControlPlaneVMs_Package(Package):

    services = [ref(ControlPlaneVMs)]

    @action
    def __install__():
        ControlPlaneVMs.NTNXPC_Extend_Disk(name="NTNXPC_Extend_Disk")
        ControlPlaneVMs.Centos_Install_Docker(name="Centos_Install_Docker")


class ControlPlaneVMs_Substrate(Substrate):

    os_type = "Linux"

    provider_spec = read_ahv_spec(
        "specs/substrate/anthosVm-spec.yaml", disk_packages={1: AHV_CENTOS}
    )
    provider_spec.spec[
        "name"
    ] = "@@{ANTHOS_CLUSTER_NAME}@@-anthos-controlVm-@@{calm_array_index}@@"

    readiness_probe = {
        "disabled": False,
        "delay_secs": "60",
        "connection_type": "SSH",
        "connection_port": 22,
        "credential": ref(CRED_OS),
    }


class ControlPlaneVMs_Deployment(Deployment):

    min_replicas = "3"
    max_replicas = "3"

    packages = [ref(ControlPlaneVMs_Package)]
    substrate = ref(ControlPlaneVMs_Substrate)


# Anthos Worker VMs Service
class WorkerNodesVMs(Service):
    """Worker Nodes VMs"""

    @action
    def Centos_Install_Docker():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/centos_install_docker.sh",
            name="Install_Docker",
        )

    @action
    def NTNXPC_Extend_Disk():
        CalmTask.Exec.escript(
            filename=LOCAL_SCRIPTS_PATH + "/ntnxpc_extend_disk.py",
            name="Extend_OS_Disk",
        )


class WorkerNodesVMs_Package(Package):

    services = [ref(WorkerNodesVMs)]

    @action
    def __install__():
        WorkerNodesVMs.NTNXPC_Extend_Disk(name="NTNXPC_Extend_Disk")
        WorkerNodesVMs.Centos_Install_Docker(name="Centos_Install_Docker")


class WorkerNodesVMs_Substrate(Substrate):

    os_type = "Linux"

    provider_spec = read_ahv_spec(
        "specs/substrate/anthosVm-spec.yaml", disk_packages={1: AHV_CENTOS}
    )
    provider_spec.spec[
        "name"
    ] = "@@{ANTHOS_CLUSTER_NAME}@@-anthos-workerVm-@@{calm_array_index}@@"

    readiness_probe = {
        "disabled": False,
        "delay_secs": "60",
        "connection_type": "SSH",
        "connection_port": 22,
        "credential": ref(CRED_OS),
    }


class WorkerNodesVMs_Deployment(Deployment):

    min_replicas = "2"
    max_replicas = "99"

    packages = [ref(WorkerNodesVMs_Package)]
    substrate = ref(WorkerNodesVMs_Substrate)


# Anthos Admin VM Service
class AdminVM(Service):
    """Admin VM"""

    dependencies = [ref(ControlPlaneVMs_Deployment), ref(WorkerNodesVMs_Deployment)]

    @action
    def __create__():
        AdminVM.Source_Variables(name="Source_Variables")
        AdminVM.Anthos_Install_CLI(name="Anthos_Install_CLI")
        AdminVM.Anthos_Create_Cluster(name="Anthos_Create_Cluster")
        AdminVM.GKE_Configure_CloudConsole(name="GKE_Configure_CloudConsole")
        AdminVM.NTNXK8S_Install_CSI(name="NTNXK8S_Install_CSI")

    @action
    def __delete__():
        AdminVM.Anthos_Reset_Cluster(name="Anthos_Reset_Cluster")

    @action
    def Gcloud_Install_SDK():

        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/gcloud_install_sdk.sh", name="Install_SDK"
        )
        # CalmTask.SetVariable.ssh(
        #     filename=LOCAL_SCRIPTS_PATH + "/gcloud_configure_account.sh",
        #     name="Configure_Gcloud",
        #     variables=["GCP_PROJECT_ID","GCP_KEY"]
        # )

    @action
    def Source_Variables():
        CalmTask.Exec.ssh(
            filename=LOCAL_SCRIPTS_PATH + "/variables.sh", name="Source_Variables"
        )

        ScaleIn = Variable.Simple.int("0", name="ScaleIn")

    @action
    def Anthos_Install_CLI():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/anthos_install_bmctl.sh",
            name="Install_CLI",
        )

    @action
    def Anthos_Create_Cluster():
        CalmTask.SetVariable.ssh(
            filename=SHARED_SCRIPTS_PATH + "/anthos_create_cluster.sh",
            name="Create_Cluster",
            variables=["KUBECONFIG"],
        )

    @action
    def Anthos_Scale_Cluster():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/anthos_scale_cluster.sh",
            name="Scale_Cluster",
        )

    @action
    def Anthos_Upgrade_Cluster():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/anthos_upgrade_cluster.sh",
            name="Upgrade_Cluster",
        )

    @action
    def Anthos_Reset_Cluster():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/anthos_reset_cluster.sh",
            name="Reset_Cluster",
        )

    @action
    def GKE_Configure_CloudConsole():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/gke_configure_cloudconsole.sh",
            name="GKE_Configure_CloudConsole",
        )

    @action
    def Centos_Install_Docker():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/centos_install_docker.sh",
            name="Install_Docker",
        )

    @action
    def NTNXPC_Extend_Disk():
        CalmTask.Exec.escript(
            filename=LOCAL_SCRIPTS_PATH + "/ntnxpc_extend_disk.py",
            name="Extend_OS_Disk",
        )

    @action
    def NTNXK8S_Install_CSI():
        CalmTask.Exec.ssh(
            filename=SHARED_SCRIPTS_PATH + "/ntnxk8s_install_csi.sh",
            name="NTNXK8S_Install_CSI",
        )

    GCP_PROJECT_ID = Variable.Simple.string("", name="GCP_PROJECT_ID")

    GCP_KEY = Variable.Simple.string("", name="GCP_KEY", is_hidden=True)

    KUBECONFIG = Variable.Simple.string("", name="KUBECONFIG")


class AdminVM_Package(Package):

    services = [ref(AdminVM)]

    @action
    def __install__():
        AdminVM.NTNXPC_Extend_Disk(name="NTNXPC_Extend_Disk")
        AdminVM.Centos_Install_Docker(name="Centos_Install_Docker")
        AdminVM.Gcloud_Install_SDK(name="Gcloud_Install_SDK")


class AdminVM_Substrate(Substrate):

    os_type = "Linux"

    provider_spec = read_ahv_spec(
        "specs/substrate/anthosVm-spec.yaml", disk_packages={1: AHV_CENTOS}
    )
    provider_spec.spec[
        "name"
    ] = "@@{ANTHOS_CLUSTER_NAME}@@-anthos-adminVm-@@{calm_array_index}@@"

    readiness_probe = {
        "disabled": False,
        "delay_secs": "60",
        "connection_type": "SSH",
        "connection_port": 22,
        "credential": ref(CRED_OS),
    }


class AdminVM_Deployment(Deployment):

    min_replicas = "1"
    max_replicas = "1"

    packages = [ref(AdminVM_Package)]
    substrate = ref(AdminVM_Substrate)


class Default(Profile):

    deployments = [
        AdminVM_Deployment,
        ControlPlaneVMs_Deployment,
        WorkerNodesVMs_Deployment,
    ]

    PYTHON_ANTHOS_GENCONFIG = Variable.Simple.string(
        "https://raw.githubusercontent.com/pipoe2h/calm-dsl/anthos-on-ahv/blueprints/anthos-on-ahv/scripts/anthos_generate_config.py",
        name="PYTHON_ANTHOS_GENCONFIG",
        label="Python Parser URL",
        description="""This script is hosted externally and produce an Anthos configuration 
            file for cluster creation with user provided inputs during launch.
            DO NOT CHANGE default value unless you will host the script in an internal repository""",
        is_hidden=True,
    )

    KUBERNETES_SERVICE_ACCOUNT = Variable.Simple.string(
        "google-cloud-console",
        name="KUBERNETES_SERVICE_ACCOUNT",
        label="Kubernetes SA Cloud Console",
        description="""
            This K8s SA is for Google Cloud Console so the K8s cluster can be managed in GKE. 
            This service account will have cluster-admin role for Google Cloud Marketplace to work. 
            Default: google-cloud-console""",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_LB_ADDRESSPOOL = Variable.Simple.string(
        "",
        name="ANTHOS_LB_ADDRESSPOOL",
        label="Anthos Load Balancing pool",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="""This is the IP address range for Load Balancing. 
            Format: XXX.XXX.XXX.XXX-YYY.YYY.YYY.YYY""",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_INGRESS_VIP = Variable.Simple.string(
        "",
        name="ANTHOS_INGRESS_VIP",
        label="Anthos Kubernetes Ingress VIP",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="""This is the IP address for Kubernetes Ingress. 
            This address MUST be within the load balancing pool. Format: XXX.XXX.XXX.XXX""",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_CONTROLPLANE_VIP = Variable.Simple.string(
        "",
        name="ANTHOS_CONTROLPLANE_VIP",
        label="Anthos cluster VIP",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="This is the IP address for Kubernetes API. Format: XXX.XXX.XXX.XXX",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_PODS_NETWORK = Variable.Simple.string(
        "172.30.0.0/16",
        name="ANTHOS_PODS_NETWORK",
        label="Anthos Kubernetes pods network",
        regex="^([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?$",
        validate_regex=True,
        description="""This is the network for your pods. Preferably do not overlap with other networks. 
            CIDR format: XXX.XXX.XXX.XXX/XX""",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_SERVICES_NETWORK = Variable.Simple.string(
        "172.31.0.0/16",
        name="ANTHOS_SERVICES_NETWORK",
        label="Anthos Kubernetes services network",
        regex="^([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?$",
        validate_regex=True,
        description="""This is the network for your services. Preferably do not overlap with other networks. 
            CIDR format: XXX.XXX.XXX.XXX/XX""",
        is_mandatory=True,
        runtime=True,
    )

    ANTHOS_VERSION = Variable.Simple.string(
        "1.6.2",
        name="ANTHOS_VERSION",
        description="The only supported versions are 1.6.x, 1.7.0 is not supported yet but can be tested.",
        regex="^(\\d+\\.)?(\\d+\\.)?(\\*|\\d+)$",
        validate_regex=True,
        label="Anthos cluster version",
        is_mandatory=True,
        runtime=True
    )

    ANTHOS_CLUSTER_NAME = Variable.Simple.string(
        "@@{calm_application_name}@@",
        name="ANTHOS_CLUSTER_NAME",
        description="Name must start with a lowercase letter followed by up to 39 lowercase letters, numbers, or hyphens, and cannot end with a hyphen. Name is permanent and unique",
        regex="^[a-z](?:[a-z0-9-]*[a-z0-9])?$",
        validate_regex=True,
        label="Anthos cluster name",
        is_mandatory=True,
        runtime=True,
    )

    NTNX_PE_STORAGE_CONTAINER = Variable.Simple.string(
        "",
        name="NTNX_PE_STORAGE_CONTAINER",
        label="Storage Container in Prism Element",
        description="""This is the Nutanix Storage Container where the requested Persistent Volume Claims will
            get their volumes created. You can enable things like compression and deduplication in a Storage Container.
            The recommendation is to create at least one storage container in Prism Element well identified for Kubernetes usage.
            This will facilitate the search of persistent volumes when the environment scales""",
        is_mandatory=True,
        runtime=True,
    )

    NTNX_PE_DATASERVICE_IP = Variable.Simple.string(
        "",
        name="NTNX_PE_DATASERVICE_IP",
        label="Data service IP address",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="""Data service is required to allow iSCSI connectivity between the 
            Kubernetes pods and the volumes created by CSI""",
        is_mandatory=True,
        runtime=True,
    )

    NTNX_PE_PORT = Variable.Simple.string(
        "9440",
        name="NTNX_PE_PORT",
        label="Prism Element port",
        regex="^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$",
        validate_regex=True,
        is_hidden=True,
    )

    NTNX_PE_IP = Variable.Simple.string(
        "",
        name="NTNX_PE_IP",
        label="Prism Element VIP",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="This is needed for the CSI driver to create persistent volumes via the API",
        is_mandatory=True,
        runtime=True,
    )

    NTNX_CSI_URL = Variable.Simple.string(
        "http://download.nutanix.com/csi/v2.3.1/csi-v2.3.1.tar.gz",
        name="NTNX_CSI_URL",
        label="Nutanix CSI Driver URL. Minimum supported version is 2.3.1",
        is_hidden=True,
    )

    OS_DISK_SIZE = Variable.Simple.int(
        "128",
        name="OS_DISK_SIZE",
        label="OS disk size",
        description="The minimum OS disk size MUST be 128GB, recommended by Google is 256GB",
        is_hidden=True,
    )

    NTNX_PC_IP = Variable.Simple.string(
        "127.0.0.1",
        name="NTNX_PC_IP",
        label="Prism Central IP",
        regex="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
        validate_regex=True,
        description="If you are using a remote Prism Central instance, use the IP address of that instance. This is used to expand the OS disk via PC API.",
        is_mandatory=True,
        runtime=True,
    )

    @action
    def ScaleOut():
        """This action will scale out worker nodes by given scale out count"""
        ScaleOut = Variable.Simple.int("1", is_mandatory=True, runtime=True)

        CalmTask.Scaling.scale_out(
            "@@{ScaleOut}@@",
            target=ref(WorkerNodesVMs_Deployment),
            name="Scale out worker nodes",
        )

        AdminVM.Source_Variables(name="Source_Variables")
        AdminVM.Anthos_Scale_Cluster(name="Anthos_Scale_Cluster")

    @action
    def ScaleIn():
        """This action will scale in workder nodes by given scale in count"""
        ScaleIn = Variable.Simple.int("1", is_mandatory=True, runtime=True)

        AdminVM.Source_Variables(name="Source_Variables")
        AdminVM.Anthos_Scale_Cluster(name="Anthos_Scale_Cluster")

        CalmTask.Scaling.scale_in(
            "@@{ScaleIn}@@",
            target=ref(WorkerNodesVMs_Deployment),
            name="Scale in worker nodes",
        )

    @action
    def UpgradeCluster():
        """This action will upgrade the Anthos cluster to a new version"""
        ANTHOS_VERSION = Variable.Simple.string(
            "",
            name="ANTHOS_VERSION",
            description="The only supported versions are 1.6.x, 1.7.0 is not supported yet but can be tested.",
            regex="^(\\d+\\.)?(\\d+\\.)?(\\*|\\d+)$",
            validate_regex=True,
            label="Anthos cluster version",
            is_mandatory=True,
            runtime=True
        )

        AdminVM.Source_Variables(name="Source_Variables")
        AdminVM.Anthos_Upgrade_Cluster(name="Anthos_Upgrade_Cluster")


class Anthos_on_AHV(Blueprint):
    """GKE Cloud Console needs access to the cluster. To retrieve the token for the service account created as part of the provisioning process, run the following commands in a terminal. You can SSH from your computer to the admin VM (@@{AdminVM.address}@@) and execute the commands from there:

1. SECRET_NAME=$(kubectl get serviceaccount @@{KUBERNETES_SERVICE_ACCOUNT}@@ -o jsonpath='{$.secrets[0].name}')
2. kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode"""

    credentials = [CRED_OS, CRED_PC, CRED_PE, CRED_GCLOUD]
    services = [AdminVM, ControlPlaneVMs, WorkerNodesVMs]
    packages = [
        AdminVM_Package,
        ControlPlaneVMs_Package,
        WorkerNodesVMs_Package,
        AHV_CENTOS,
    ]
    substrates = [
        AdminVM_Substrate,
        ControlPlaneVMs_Substrate,
        WorkerNodesVMs_Substrate,
    ]
    profiles = [Default]


def main():
    print(Anthos_on_AHV.json_dumps(pprint=True))


if __name__ == "__main__":
    main()
