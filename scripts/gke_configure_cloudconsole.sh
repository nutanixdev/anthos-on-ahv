source ~/variables.sh
echo '======Configure Cloud console======'
# ============== DO NO CHANGE AFTER THIS ===============

cat <<EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cloud-console-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
EOF

kubectl create serviceaccount ${KSA_NAME}
kubectl create clusterrolebinding ${KSA_NAME}-view \
--clusterrole view --serviceaccount default:${KSA_NAME}
kubectl create clusterrolebinding ${KSA_NAME}-reader \
--clusterrole cloud-console-reader --serviceaccount default:${KSA_NAME}

kubectl create clusterrolebinding ${KSA_NAME}-admin \
--clusterrole cluster-admin --serviceaccount default:${KSA_NAME}
