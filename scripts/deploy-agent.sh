#!/usr/bin/env bash
set -euo pipefail

: "${RESOURCE_GROUP:?Set RESOURCE_GROUP}"
: "${APIM_NAME:?Set APIM_NAME to a globally unique Developer gateway name}"
: "${PUBLISHER_EMAIL:?Set PUBLISHER_EMAIL}"
: "${FOUNDRY_PROJECT_ID:?Set FOUNDRY_PROJECT_ID to the ARM resource ID of your Foundry project}"
: "${MODEL_DEPLOYMENT:?Set MODEL_DEPLOYMENT to an existing prompt-agent model deployment}"
AGENT_NAME=${AGENT_NAME:-sc500-token-limit-demo}
LOCATION=${LOCATION:-westeurope}
TOKENS_PER_MINUTE=${TOKENS_PER_MINUTE:-200}
SITE_ORIGIN=${SITE_ORIGIN:-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! "$FOUNDRY_PROJECT_ID" =~ ^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.CognitiveServices/accounts/([^/]+)/projects/([^/]+)$ ]]; then
  echo 'FOUNDRY_PROJECT_ID must be the full Foundry project ARM resource ID.' >&2
  exit 1
fi
PROJECT_URL="https://${BASH_REMATCH[1]}.services.ai.azure.com/api/projects/${BASH_REMATCH[2]}"
if [[ ! "$AGENT_NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
  echo 'AGENT_NAME must be 1–63 alphanumeric characters or hyphens, with alphanumeric ends.' >&2
  exit 1
fi
if [[ -n "$SITE_ORIGIN" && ! "$SITE_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
  echo 'SITE_ORIGIN must be an HTTPS origin without a path or trailing slash.' >&2
  exit 1
fi

AGENTS=$(az rest --method get --resource https://ai.azure.com --url "$PROJECT_URL/agents?api-version=v1")
while :; do
  if jq -e --arg name "$AGENT_NAME" '.data[] | select(.name == $name)' <<<"$AGENTS" >/dev/null; then
    printf 'Using existing agent %s.\n' "$AGENT_NAME"
    break
  fi
  NEXT=$(jq -r '.nextLink // empty' <<<"$AGENTS")
  if [[ -z "$NEXT" ]]; then
    BODY=$(jq -n --arg name "$AGENT_NAME" --arg model "$MODEL_DEPLOYMENT" '{
      name: $name,
      definition: {
        kind: "prompt", model: $model,
        instructions: "You are an Azure training assistant for an SC-500 demo. Give short, clear answers about Azure API Management and Microsoft Foundry."
      }
    }')
    az rest --method post --resource https://ai.azure.com --url "$PROJECT_URL/agents?api-version=v1" --body "$BODY" -o none
    break
  fi
  AGENTS=$(az rest --method get --resource https://ai.azure.com --url "$NEXT")
done

az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none
PRINCIPAL=$(az deployment group create -g "$RESOURCE_GROUP" -n sc500-agent-gateway -f "$ROOT/infra/agent-gateway.bicep" \
  -p apimName="$APIM_NAME" publisherEmail="$PUBLISHER_EMAIL" location="$LOCATION" \
  --query properties.outputs.principalId.value -o tsv)
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role eed3b665-ab3a-47b6-8f48-c9382fb1dad6 --scope "$FOUNDRY_PROJECT_ID/agents/$AGENT_NAME" -o none
az deployment group create -g "$RESOURCE_GROUP" -n sc500-agent-api -f "$ROOT/infra/agent-api.bicep" \
  -p apimName="$APIM_NAME" agentEndpoint="$PROJECT_URL/agents/$AGENT_NAME/endpoint/protocols/openai" \
     siteOrigin="$SITE_ORIGIN" tokensPerMinute="$TOKENS_PER_MINUTE" -o none
printf 'Agent gateway: https://%s.azure-api.net/agent/responses\n' "$APIM_NAME"
