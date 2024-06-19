#!/bin/bash

# This script will install AIO to an Arc-enabled a kubernetes cluster (see ./arc_setup.sh)
# for more information, see https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-deploy-iot-operations

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
  if [ -z "${RESOURCE_GROUP+x}" ]; then
    echo "The required variables were not found. See the README.md for more information" 1>&2
    exit 1
  fi
fi

# Exits on error (e), exits if variables not defined (u), prints debug statements (x) and makes sure errors aren't masked (o pipefail)
set -euxo pipefail

echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
echo fs.file-max = 100000 | sudo tee -a /etc/sysctl.conf

sudo sysctl -p

# Assigns the necessary write permissions to the current user
# see docs linked above for other options
user_id="$(az ad signed-in-user show --query id -o tsv)"
resource_group_id="$(az group show --name "${RESOURCE_GROUP}" -o tsv --query id)"
az role assignment create --assignee "${user_id}" --role "Role Based Access Control Administrator" --scope "${resource_group_id}"

# Creates a Key Vault with the required permissions model unless it already exists
if ! kevault_id="$(az keyvault show --name "${KEYVAULT_NAME}" -o tsv --query id 2> /dev/null)"; then
  az keyvault create --enable-rbac-authorization false --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}"
fi

# Ads the Az IOT extension to the CLI
az extension add --upgrade --name azure-iot-ops
# Deploys Az IOT resources
az iot ops init --cluster "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --kv-id "${kevault_id}"

az iot ops check