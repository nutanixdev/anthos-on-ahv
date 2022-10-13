# ============== DO NO CHANGE AFTER THIS ===============
source ~/variables.sh
echo '======Installing Nutanix CSI driver======'
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add nutanix https://nutanix.github.io/helm/
helm repo update
  
helm upgrade --install nutanix-csi nutanix/nutanix-csi-storage \
  --namespace ntnx-system --create-namespace \
  --set volumeClass=true \
  --set prismEndPoint=${NTNX_PE_IP} \
  --set username=${NTNX_PE_USERNAME} \
  --set password=${NTNX_PE_PASSWORD} \
  --set storageContainer=${NTNX_PE_STORAGE_CONTAINER} \
  --set fsType=xfs \
  --set defaultStorageClass=volume \
  --set dynamicFileClass=false \
  --set fileServerName=null