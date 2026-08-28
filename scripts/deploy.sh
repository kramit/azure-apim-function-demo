#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP=${RESOURCE_GROUP:-azure-apim-function-demo-rg}
LOCATION=${LOCATION:-westeurope}
RESOURCE_PREFIX=${RESOURCE_PREFIX:-apimfunc$RANDOM}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

command -v az >/dev/null || { echo 'Azure CLI is required.' >&2; exit 1; }
az account show --output none
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
DEPLOYMENT=$(az deployment group create --resource-group "$RESOURCE_GROUP" --template-file "$ROOT/infra/main.bicep" --parameters location="$LOCATION" resourcePrefix="$RESOURCE_PREFIX" --query properties.outputs --output json)
FUNCTION_APP=$(jq -r '.functionAppName.value' <<<"$DEPLOYMENT")
APIM_NAME=$(jq -r '.apimName.value' <<<"$DEPLOYMENT")
printf '%s\n' "Deploying function code to $FUNCTION_APP. APIM provisioning can take several minutes."
(cd "$ROOT/function" && zip -qr "$ROOT/function-package.zip" .)
az functionapp deployment source config-zip --resource-group "$RESOURCE_GROUP" --name "$FUNCTION_APP" --src "$ROOT/function-package.zip" --output none
rm -f "$ROOT/function-package.zip"
printf 'RESOURCE_GROUP=%s\nFUNCTION_APP=%s\nAPIM_NAME=%s\n' "$RESOURCE_GROUP" "$FUNCTION_APP" "$APIM_NAME"
printf 'Run scripts/test-api.sh with these values after APIM provisioning completes.\n'
