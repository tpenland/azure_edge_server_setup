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
# export RANDOM_ID="$(openssl rand -hex 3)"
export RESOURCE_GROUP="rg-aio001-tp"
export REGION=EastUS
export VM_NAME="aio001-tp"
export USERNAME=azureuser
export VM_IMAGE="Canonical:0001-com-ubuntu-minimal-jammy:minimal-22_04-lts-gen2:latest"

if [ "$(az group exists --name ${RESOURCE_GROUP})" = false ]; then
  az group create --location "${REGION}" --resource-group "${RESOURCE_GROUP}"
fi

# https://learn.microsoft.com/en-us/cli/azure/vm?view=azure-cli-latest#az-vm-create
az vm create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --image "${VM_IMAGE}" \
    --admin-username "${VM_USERNAME}" \
    --size "${VM_SIZE}" \
    --assign-identity \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --verbose

IP_ADDRESS=$(az vm show --show-details --resource-group "${RESOURCE_GROUP}" --name "${VM_NAME}" --query publicIps --output tsv)
export IP_ADDRESS
echo "VM IP Address: ${IP_ADDRESS}"

nicId=$(az vm show -n "$VM_NAME" -g "$RESOURCE_GROUP" --query 'networkProfile.networkInterfaces[].id' -o tsv)
read -d '' ipId subnetId <<< "$(az network nic show --ids "$nicId" --query '[ipConfigurations[].publicIPAddress.id, ipConfigurations[].subnet.id]' -o tsv)"
vmIpAddress=$(az network public-ip show --ids "$ipId" --query ipAddress -o tsv)

echo ipId: "$ipId"
echo vmIpAddress: "$vmIpAddress"
echo subnetId: "$subnetId"
# ssh -i ~/.ssh/id_rsa azureuser@40.71.1.19
# ssh -o StrictHostKeyChecking=no $USERNAME@$IP_ADDRESS
# scp -r *.* azureuser@40.71.1.19:/home/azureuser/edge_setup

