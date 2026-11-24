#!/usr/bin/env bash
set -euo pipefail

: "${RESOURCE_GROUP:?Set RESOURCE_GROUP}"
: "${APIM_NAME:?Set APIM_NAME}"
SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-sc500-agent-demo}
MAX_REQUESTS=${MAX_REQUESTS:-15}
SUBSCRIPTION=$(az account show --query id -o tsv)
ARM="https://management.azure.com/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_NAME"
KEY=$(az rest --method post --url "$ARM/subscriptions/$SUBSCRIPTION_ID/listSecrets?api-version=2022-08-01" --query primaryKey -o tsv)
[[ -n "$KEY" ]]
URL="https://$APIM_NAME.azure-api.net/agent/responses"
BODY='{"input":"In 35 to 50 words, explain what Azure API Management does."}'
RESPONSES=$(mktemp -d)
trap 'rm -f "$RESPONSES/headers" "$RESPONSES/body"; rmdir "$RESPONSES"' EXIT

STATUS=$(curl -sS --max-time 45 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d "$BODY" "$URL")
[[ "$STATUS" == 401 ]]
echo 'Without key: HTTP 401.'

for (( attempt=1; attempt<=MAX_REQUESTS; attempt++ )); do
  STATUS=$(curl -sS --max-time 45 -D "$RESPONSES/headers" -o "$RESPONSES/body" -w '%{http_code}' \
    -H 'Content-Type: application/json' -H "Ocp-Apim-Subscription-Key: $KEY" -d "$BODY" "$URL")
  case "$STATUS" in
    200)
      jq -e '.usage.total_tokens > 0 and any(.output[]; .type == "message")' "$RESPONSES/body" >/dev/null
      awk 'tolower($1) == "x-tokens-consumed:" { sub(/\r$/, "", $2); if ($2+0 > 0) found=1 } END { exit !found }' "$RESPONSES/headers"
      echo "Request $attempt: HTTP 200 and APIM token accounting verified."
      ;;
    429)
      if (( attempt == 1 )); then
        echo 'Counter already exhausted. Wait a minute and retry.' >&2
        exit 1
      fi
      awk 'tolower($1) == "retry-after:" { found=1 } END { exit !found }' "$RESPONSES/headers"
      echo "Request $attempt: HTTP 429 with Retry-After."
      exit 0
      ;;
    *)
      echo "Request $attempt: unexpected HTTP $STATUS" >&2
      cat "$RESPONSES/body" >&2
      exit 1
      ;;
  esac
done
echo 'Rate limit was not reached. Check the deployed limit and MAX_REQUESTS.' >&2
exit 1
