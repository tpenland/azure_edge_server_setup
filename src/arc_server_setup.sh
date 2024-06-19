#!/bin/bash

# Setting up Azure Arc on a server

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
  if [ -z "${SUBSCRIPTION_ID}" ]; then
    echo "The required variables were not found. See the README.md for more information" 1>&2
    exit 1
  fi
fi

# Exits on error (e), exits if variables not defined (u), prints debug statements (x) and makes sure errors aren't masked (o pipefail)
set -euxo pipefail

# Create service principal for enabling the Arc connection if one does not already exist.
if [ -z "${SERVICE_PRINCIPAL_APP_ID}" ]; then
  SERVICE_PRINCIPAL_PASSWORD=$(az ad sp create-for-rbac -n "${SERVICE_PRINCIPAL_DISPLAY_NAME}" --role contributor --scopes "/subscriptions/${SUBSCRIPTION_ID}" --query "password" --output tsv)
  SERVICE_PRINCIPAL_APP_ID=$(az ad sp list --display-name "${SERVICE_PRINCIPAL_DISPLAY_NAME}" --query "[].appId" --output tsv)
  
  echo '---------------Created new Service Principal------------------'
  echo 'Store the following confidential information. The password cannot be retrieved.'
  echo 'Service principal App Id: '"${SERVICE_PRINCIPAL_APP_ID}"
  echo 'Service principal password: '"${SERVICE_PRINCIPAL_PASSWORD}"
fi

## Install aczm agent
wget https://aka.ms/azcmagent -O ./install_linux_azcmagent.sh
bash ./install_linux_azcmagent.sh

## Run connect command
sudo azcmagent connect \
  --service-principal-id "${SERVICE_PRINCIPAL_APP_ID}" \
  --service-principal-secret "${SERVICE_PRINCIPAL_PASSWORD}" \
  --resource-group "${RESOURCE_GROUP}" \
  --tenant-id "${TENANT_ID}" \
  --location "${LOCATION}" \
  --subscription-id "${SUBSCRIPTION_ID}" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

## Add SSH extension to the Arc-Enabled device
az extension add --name ssh

## Wait for Arc VM to be deployed
sleep 5m

# Get name of server this script is running on
server_name=$(hostname)

## Add SSH connectivity to the device
az rest --method put --uri https://management.azure.com/subscriptions/"${SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.HybridCompute/machines/"${server_name}"/providers/Microsoft.HybridConnectivity/endpoints/default/serviceconfigurations/SSH?api-version=2023-03-15 --body "{\"properties\": {\"serviceName\": \"SSH\", \"port\": 22}}"
