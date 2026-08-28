#!/usr/bin/env bash
set -euo pipefail

: "${RESOURCE_GROUP:?Set RESOURCE_GROUP}"
: "${FUNCTION_APP:?Set FUNCTION_APP}"
: "${APIM_NAME:?Set APIM_NAME}"
SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-demo-subscription}
DIRECT_URL="https://${FUNCTION_APP}.azurewebsites.net/api/hello?name=direct"
APIM_URL="https://${APIM_NAME}.azure-api.net/hello/hello?name=apim"

echo 'Checking Function backend...'
curl --fail --silent --show-error "$DIRECT_URL" | jq -e '.backend == "Azure Functions"' >/dev/null
echo 'Checking APIM rejects a missing subscription key...'
[[ $(curl --silent --output /dev/null --write-out '%{http_code}' "$APIM_URL") == 401 ]]
KEY=$(az rest --method POST --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/subscriptions/${SUBSCRIPTION_ID}/listSecrets?api-version=2022-08-01" --query primaryKey --output tsv)
echo 'Checking APIM forwards a valid subscription-key request...'
curl --fail --silent --show-error -H "Ocp-Apim-Subscription-Key: $KEY" "$APIM_URL" | jq -e '.backend == "Azure Functions"' >/dev/null
echo 'All Function and APIM tests passed.'
