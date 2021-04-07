function join { 
    local IFS="$1"; shift; echo "$*"; 
}

if [ ! -f ~/google_application_credentials ]; then
    echo '@@{CRED_GCLOUD.secret}@@' > ~/google_application_credentials
fi

if [ ! -f ~/.ssh/id_rsa ]; then
    echo '@@{CRED_OS.secret}@@' > ~/.ssh/id_rsa
fi

if [ "@@{ScaleIn}@@" -eq "0" ]; then
    export ANTHOS_WORKERNODES_ADDRESSES="@@{WorkerNodesVMs.address}@@"
else
    IFS=',' read -r -a array <<< "@@{WorkerNodesVMs.address}@@"
    COUNT=@@{ScaleIn}@@
    export ANTHOS_WORKERNODES_ADDRESSES=$(join , ${array[@]::${#array[@]}-$COUNT})
fi

GOOGLE_PROJECT_ID=$(grep project_id ~/google_application_credentials  | awk -F'"' '{print $4}')

cat << EOF > ./variables.sh
export ANTHOS_VERSION="@@{ANTHOS_VERSION}@@"
export GOOGLE_APPLICATION_CREDENTIALS="/home/@@{CRED_OS.username}@@/google_application_credentials"
export ANTHOS_TEMPLATE_PATH="/home/@@{CRED_OS.username}@@/baremetal/bmctl-workspace/@@{ANTHOS_CLUSTER_NAME}@@/@@{ANTHOS_CLUSTER_NAME}@@.yaml"
export ANTHOS_SSH_KEY="/home/@@{CRED_OS.username}@@/.ssh/id_rsa"
export ANTHOS_CLUSTER_TYPE="hybrid"
export ANTHOS_CONTROLPLANE_ADDRESSES="@@{ControlPlaneVMs.address}@@"
export ANTHOS_LVPNODEMOUNTS="/home/@@{CRED_OS.username}@@/localpv-disk"
export ANTHOS_LVPSHARE="/home/@@{CRED_OS.username}@@/localpv-share"
export ANTHOS_LOGINUSER="@@{CRED_OS.username}@@"
export ANTHOS_WORKERNODES_ADDRESSES="${ANTHOS_WORKERNODES_ADDRESSES}"
export ANTHOS_CLUSTER_NAME="@@{ANTHOS_CLUSTER_NAME}@@"
export ANTHOS_CONTROLPLANE_VIP=@@{ANTHOS_CONTROLPLANE_VIP}@@
export ANTHOS_PODS_NETWORK=@@{ANTHOS_PODS_NETWORK}@@
export ANTHOS_SERVICES_NETWORK=@@{ANTHOS_SERVICES_NETWORK}@@
export ANTHOS_INGRESS_VIP=@@{ANTHOS_INGRESS_VIP}@@
export ANTHOS_LB_ADDRESSPOOL=@@{ANTHOS_LB_ADDRESSPOOL}@@
export PYTHON_ANTHOS_GENCONFIG="@@{PYTHON_ANTHOS_GENCONFIG}@@"
export KSA_NAME=@@{KUBERNETES_SERVICE_ACCOUNT}@@
export NTNX_CSI_URL=@@{NTNX_CSI_URL}@@
export NTNX_PE_IP=@@{NTNX_PE_IP}@@
export NTNX_PE_PORT=@@{NTNX_PE_PORT}@@
export NTNX_PE_USERNAME=@@{CRED_PE.username}@@
export NTNX_PE_PASSWORD=@@{CRED_PE.secret}@@
export NTNX_PE_DATASERVICE_IP=@@{NTNX_PE_DATASERVICE_IP}@@
export NTNX_PE_STORAGE_CONTAINER=@@{NTNX_PE_STORAGE_CONTAINER}@@
export KUBECONFIG="/home/@@{CRED_OS.username}@@/baremetal/bmctl-workspace/@@{ANTHOS_CLUSTER_NAME}@@/@@{ANTHOS_CLUSTER_NAME}@@-kubeconfig"
export GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID
EOF

source ./variables.sh
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
