#!/bin/bash

# This script will Arc enable a kubernetes cluster. For more information see
# https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#arc-enable-your-cluster

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

# This is the officially assigned Microsoft Entra Id for Arc
ms_arc_entra_id=bc313c14-388c-4e7d-a58e-70017303ee3b

az provider register -n "Microsoft.ExtendedLocation"
az provider register -n "Microsoft.Kubernetes"
az provider register -n "Microsoft.KubernetesConfiguration"
az provider register -n "Microsoft.IoTOperationsOrchestrator"
az provider register -n "Microsoft.IoTOperationsMQ"
az provider register -n "Microsoft.IoTOperationsDataProcessor"
az provider register -n "Microsoft.DeviceRegistry"

# Add connectedk8s extension to your az cli
az extension add --name connectedk8s

if [ "$(az group exists --name "${RESOURCE_GROUP}")" = false ]; then
  az group create --location "${LOCATION}" --resource-group "${RESOURCE_GROUP}" --subscription "${SUBSCRIPTION_ID}"
fi

# Connect the cluster to Arc
az connectedk8s connect -n "${CLUSTER_NAME}" -l "${LOCATION}" -g "${RESOURCE_GROUP}" --subscription "${SUBSCRIPTION_ID}"

# Enable features used by AIO
object_id=$(az ad sp show --id "${ms_arc_entra_id}" --query id -o tsv)
az connectedk8s enable-features -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}" --custom-locations-oid "${object_id}" --features cluster-connect custom-locations
