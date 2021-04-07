# ============== DO NO CHANGE AFTER THIS ===============
source ./variables.sh

# Reset Anthos cluster before deleting
cd ~/baremetal
echo "The reset process can take few minutes depending on the number of nodes and applications running on it"
if ./bmctl reset -c ${ANTHOS_CLUSTER_NAME} > /dev/null ; then
    echo "The cluster has been unregistered."
    exit 0
else
    echo "The process has failed. Deletion continues for virtual servers. Remember to manually clean up orphaned objects in GCP."
    exit 0
fi
