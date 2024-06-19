#!/bin/bash

# This script installs the necessary extensions for Edge Storage Accelerator.

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

az config set extension.use_dynamic_install=yes_without_prompt

# Add the Open Service Mesh (OSM) extension
az k8s-extension create \
  --resource-group  "${RESOURCE_GROUP}" \
  --cluster-name  "${CLUSTER_NAME}" \
  --cluster-type connectedClusters \
  --extension-type Microsoft.openservicemesh \
  --scope cluster \
  --name osm

# Generates the config file needed in the next step
echo '{
    "acstorController.enabled": false,
    "feature.diskStorageClass": "local-path",
    "feature.enableEdgeVolume": true,
    "feature.enableCacheVolume": false
}' >> config.json

az k8s-extension create \
  --resource-group  "${RESOURCE_GROUP}" \
  --cluster-name  "${CLUSTER_NAME}" \
  --cluster-type connectedClusters \
  --name esa \
  --extension-type microsoft.edgestorageaccelerator \
  --config-file "config.json"
