# ============== DO NO CHANGE AFTER THIS ===============
source ~/variables.sh
echo '======Create Anthos cluster======'
echo "invoking $ANTHOS_CLUSTER_NAME"

# Install Python 3
sudo dnf install -y python3

# Install PyYAML
sudo python3 -m pip install pyyaml

# Create Anthos configuration file
cd ~/baremetal
curl -s $PYTHON_ANTHOS_GENCONFIG | python3

# Create Anthos Kubernetes cluster
echo "Creating Anthos cluster. This can take about 45 minutes depending on Internet connectivity"
if ./bmctl create cluster -c $ANTHOS_CLUSTER_NAME > /dev/null ; then
    export KUBECONFIG=$HOME/baremetal/bmctl-workspace/${ANTHOS_CLUSTER_NAME}/${ANTHOS_CLUSTER_NAME}-kubeconfig
    echo "KUBECONFIG=$KUBECONFIG"
    mkdir -p $HOME/.kube
    cp $KUBECONFIG $HOME/.kube/config
else
    echo "Check the logs located in $HOME/baremetal/bmctl-workspace/${ANTHOS_CLUSTER_NAME}/log"
    exit 1
fi

