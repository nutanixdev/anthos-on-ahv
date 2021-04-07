# ============== DO NO CHANGE AFTER THIS ===============
source ~/variables.sh

current_anthos_version=$(kubectl get cluster --all-namespaces -o yaml | grep "^ *anthosBareMetalVersion:" | tr -s ' ' | cut -d ' ' -f3 | uniq )
if [ "$current_anthos_version" == "$ANTHOS_VERSION" ]
then
    echo "Anthos cluster already on required version: $current_anthos_version"
    exit 0
fi
# Upgrade Anthos CLI (bmctl)
cd ~/baremetal

gsutil cp gs://anthos-baremetal-release/bmctl/$ANTHOS_VERSION/linux-amd64/bmctl bmctl
chmod a+x bmctl

# Updating Anthos version in config file
sed -i '/anthosBareMetalVersion/s/:.*$/: '"${ANTHOS_VERSION}"'/' $HOME/baremetal/bmctl-workspace/${ANTHOS_CLUSTER_NAME}/${ANTHOS_CLUSTER_NAME}.yaml

# Upgrading Anthos cluster
echo "The upgrade process can take a while depending on the number of nodes and applications running on it"
if ./bmctl upgrade cluster -c ${ANTHOS_CLUSTER_NAME} --kubeconfig ${KUBECONFIG} > /dev/null ; then
    echo "The cluster has been upgraded to: Anthos ver. ${ANTHOS_VERSION}"
    exit 0
else
    echo "Check the logs located in $HOME/baremetal/bmctl-workspace/${ANTHOS_CLUSTER_NAME}/log"
    exit 1
fi
