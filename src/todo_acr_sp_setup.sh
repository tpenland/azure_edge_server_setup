ACR_NAME=acrihdev
SERVICE_PRINCIPAL_NAME=acrihdev-kitchenos-sp
SECRET_NAME=acrihdev-secret
NAMESPACE=yolo

ACR_REGISTRY_ID="$(az acr show --name "${ACR_NAME}" --query id --output tsv)"

PASSWORD="$(az ad sp create-for-rbac --name "${SERVICE_PRINCIPAL_NAME}" --scopes "${ACR_REGISTRY_ID}" --role acrpull --query "password" --output tsv)"
USER_NAME="$(az ad sp list --display-name "${SERVICE_PRINCIPAL_NAME}" --query "[].appId" --output tsv)"

echo 'Service principal App Id: '"${USER_NAME}"
echo 'Service principal password: '"${PASSWORD}"

kubectl create secret docker-registry "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --docker-server="${ACR_NAME}".azurecr.io \
  --docker-username="${USER_NAME}" \
  --docker-password="${PASSWORD}"

docker tag yolo9 acrihdev.azurecr.io/yolo9:v1.0y

docker push acrihdev.azurecr.io/yolo9:v1.0