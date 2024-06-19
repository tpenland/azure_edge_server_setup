#!/bin/bash

# PREREQUISITE: This script assumes that you have run the esa_setup.sh or are on a machine that has previously setup ESA.
# The purpose of this script is to setup bottomless cloud ingest for ESA. This entails the following:
#   1. Create a storage account if one does not already exist (based on STORAGE_ACCOUNT_NAME from config.env)
#   2. Create a blob container in the storage account if one does not already exist (based on BLOB_CONTAINER_NAME from config.env)
#   3. Generates a SAS token for the blob container
#   4. Create a kubernetes secret from the SAS token
#   5. Creates a Persistent Volume Claim (https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims)
#   6. Links PVC to ESA via the edgevolume kubernetes resource

# See README.md for more information about expected configuration file variables and values
usage() {
    echo "Usage:   $0 configFile" 1>&2
    echo "Example: $0 ./config.env" 1>&2
    exit 1
}

if [ $# -eq 0 ]; then
  usage
elif [ ! -f "$1" ]; then
  echo "Cannot find file: $1" 1>&2
  exit 1
else
  source "$1"
  if [ -z "${SUBSCRIPTION_ID+x}" ]; then
    echo "The required variables were not found. See the README.md for more information" 1>&2
    exit 1
  fi
fi

# Exits on error (e), exits if variables not defined (u), prints debug statements (x) and makes sure errors aren't masked (o pipefail)
set -euxo pipefail

k8s_secret_name="${STORAGE_ACCOUNT_NAME}"-secret

# Create a storage account in the resource group if it doesn't already exist
if [ ! "$(az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP}" 2> /dev/null)" ]; then
  az storage account create \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_RAGRS \
    --kind StorageV2 \
    --allow-blob-public-access false
fi

connection_string="$(az storage account show-connection-string -n "${STORAGE_ACCOUNT_NAME}" -g "${RESOURCE_GROUP}" --query 'connectionString' -o tsv)"

# Create blob container if it does not exist
if [ "$(az storage container exists -n "${BLOB_CONTAINER_NAME}" --connection-string "${connection_string}" --query 'exists')" = false ]; then
    az storage container create -n "${BLOB_CONTAINER_NAME}" --connection-string "${connection_string}"
fi

sas_token=$(az storage container generate-sas \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --expiry "${SAS_EXPIRATION_DATE}" \
  --name "${BLOB_CONTAINER_NAME}" \
  --permissions acdrw \
  --connection-string "${connection_string}")

# remove the start and end quotes
sas_token=$(echo "${sas_token}" | tr -d '"')

# Create kubernetes namespace if it does not exist
if ! kubectl get ns | grep "${KUBES_NAMESPACE}" 1>/dev/null; then 
    kubectl create namespace "${KUBES_NAMESPACE}"
fi

# Create kubernetes secret from sas token
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${k8s_secret_name}
  namespace: ${KUBES_NAMESPACE}
stringData:
  authType: SAS
  # Container level SAS (must have ? prefixed)
  storageaccountsas: \"?${sas_token}\"
type: Opaque
EOF

# Alternative way to create the secret but it appears to have a bug
# kubectl create secret generic -n "${KUBES_NAMESPACE}" "${k8s_secret_name}" --from-literal=storageaccountsas="${sas_token}"

# Create PVC that will used by ESA
kubectl apply -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  ### CREATE A NAME FOR YOUR PVC ###
  name: ${ESA_PVC_NAME}
  annotations:
  ### USE A NAMESPACE THAT MATCHES YOUR INTENDED CONSUMING POD OR 'DEFAULT' ###
  namespace: ${KUBES_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: cloud-backed-sc
EOF

volume_name=$(kubectl get edgevolumes.esahydra.azure.net -o jsonpath="{.items[0].metadata.name}")
blob_endpoint=$(az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'primaryEndpoints.blob')

# Update ESA with necessary information to sync PVC with the blob container
kubectl patch edgevolumes.esahydra.azure.net "${volume_name}" --type=json -p='[{"op": "add", "path": "/spec/subvolumes/-", "value": {"path": "results", "auth": {"authType": "SAS", "secretName": '\""${k8s_secret_name}"\"', "secretNamespace": '\""${KUBES_NAMESPACE}"\"'}, "container": '\""${BLOB_CONTAINER_NAME}"\"', "storageaccountendpoint": '"${blob_endpoint}"'}}]'

