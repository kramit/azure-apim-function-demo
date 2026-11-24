# SC-500 live demo · Subscription keys and agent token limits

[Open the interactive lab](https://brave-coast-05f5d1003.6.azurestaticapps.net)

## What to demonstrate

| Request | Gateway | Expected result |
| --- | --- | --- |
| Greeting without a subscription key | Consumption | HTTP 401 |
| Greeting with the greeting subscription key | Consumption | HTTP 200 and a JSON greeting |
| Agent prompt with the agent subscription key | Developer | HTTP 200, agent reply, and token accounting |
| Additional prompts after consuming the subscription's token allowance | Developer | HTTP 429 and a retry interval |

The greeting API forwards to an Azure Function. The agent API forwards to one
Foundry prompt agent's Responses endpoint using the Developer gateway's
system-assigned managed identity. Its Foundry Agent Consumer role is scoped to
that agent. Both APIs require their own APIM subscription keys.

Consumption APIM supports the greeting lab's subscription-key check.
The [LLM token-limit policy](https://learn.microsoft.com/azure/api-management/llm-token-limit-policy)
requires a supported tier such as Developer. Developer is a continuously billed
non-production tier. Foundry inference is also billed by Azure.

```text
Browser  ── GET /hello/hello  ── Consumption APIM ── Azure Function
         └─ POST /agent/responses ── Developer APIM ── Foundry agent
                APIM subscription key      Managed identity to Foundry
```

## Prerequisites

- Azure CLI with Bicep, Bash, jq, curl, and zip.
- An Azure subscription with permission to create the demo resources and assign a role at the Foundry agent scope.
- An existing Foundry project and a model deployment that supports prompt agents.
- Foundry User permissions to create the agent in that project.

## Deploy both demos

For a CLI-only deployment, omit `SITE_ORIGIN`. For the interactive page,
create the web app first so you can pass its origin to both gateways.

```bash
export RESOURCE_GROUP=azure-apim-function-demo-rg
export LOCATION=westeurope
```

To create the web app with the Azure CLI, use a globally unique name and capture
the hostname as the origin that the gateways should allow.

```bash
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
SITE_HOST=$(az staticwebapp create --resource-group "$RESOURCE_GROUP" \
  --name '<unique-site-name>' --location westeurope --sku Free \
  --query defaultHostname --output tsv)
export SITE_ORIGIN="https://$SITE_HOST"
```

Deploy both gateway APIs.

```bash
RESOURCE_PREFIX='<unique-lowercase-prefix>' ./scripts/deploy.sh

APIM_NAME='<unique-developer-apim-name>' \
PUBLISHER_EMAIL='<your-azure-publisher-email>' \
FOUNDRY_PROJECT_ID='/subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.CognitiveServices/accounts/<account>/projects/<project>' \
MODEL_DEPLOYMENT='<model-deployment-name>' \
TOKENS_PER_MINUTE=200 \
./scripts/deploy-agent.sh
```

The agent script creates `sc500-token-limit-demo` if needed. You can set
`AGENT_NAME` to use another name. An existing agent with that name is reused.
The model deployment setting is used when creating a new agent. The Bicep
templates deploy the Developer gateway and the API, operation, subscription,
and policy. Developer gateway provisioning can take 30–40 minutes.
Allow time for the agent role assignment to propagate before smoke testing.
See the [Azure provisioning guide](https://learn.microsoft.com/azure/api-management/get-started-create-service-instance-cli).

To publish your own copy of the page, set the endpoint defaults in
`site/index.html` to the two deployed gateway URLs. Upload the buildless
`site/` folder to Azure Static Web Apps. The included GitHub Actions workflow
runs on pushes to `main` that change the page and requires the Static Web App
deployment token in the repository secret `SC500_STATIC_WEB_APP_TOKEN`.
Only the Static Web Apps deployment credential goes into that Actions secret.
The page obtains APIM keys from the presenter at runtime.

## Run it in class

1. Open the lab and send the greeting without a key. Point out HTTP 401.
2. In the Consumption gateway, find **Subscriptions**, then **Demo test subscription** (`demo-subscription`). Paste the primary or secondary key into the greeting key field. Send again and compare the HTTP 200 JSON response.
3. In the Developer gateway, find **Subscriptions**, then **SC-500 Agent Demo** (`sc500-agent-demo`). Enter its key in the agent panel and send the sample prompt.
4. Compare **This response** and **Remaining**. The gateway counts prompt and completion tokens from the backend usage. The sample policy sends `X-Tokens-Consumed`, `X-Remaining-Tokens`, and `X-Token-Rate-Limit`.
5. Send several prompts within a minute. A longer requested answer uses more tokens. Once the counter is exhausted, the next request returns HTTP 429. Wait for the indicated `Retry-After` interval and send again.
6. Close the page or clear the key fields when you finish.

The 200 TPM demo limit is shared by callers using the same APIM subscription,
including its primary and secondary keys. The gateway measures completed
requests, so an in-flight request can take usage above the limit before later
requests are rejected. The agent API forwards a nonempty text prompt, uses
non-streaming responses, and caps model output at 250 tokens per request.
The rate limit applies to requests routed through this gateway. Foundry
identities with direct agent access can invoke the separate Foundry endpoint.

## CLI verification

Run the [greeting tests](../README.md#test) with the Consumption gateway's
deployment outputs. Then run the agent smoke test after the Developer gateway
is ready. It retrieves the key from Azure without printing it and checks the
missing-key response, the successful response and accounting header, and
throttling with a retry interval.

```bash
RESOURCE_GROUP=azure-apim-function-demo-rg \
APIM_NAME='<developer-apim-name>' \
./scripts/test-agent.sh
```

If the first keyed request is already throttled, retry after the current
window expires. For a customized limit, adjust `MAX_REQUESTS` to suit the demo.

To inspect a single agent exchange from the terminal, set
`AGENT_APIM_SUBSCRIPTION_KEY` in your shell and call the Developer gateway.
The `-i` flag includes the APIM token headers in the output.

```bash
curl -i 'https://<developer-apim-name>.azure-api.net/agent/responses' \
  -H "Ocp-Apim-Subscription-Key: ${AGENT_APIM_SUBSCRIPTION_KEY:?Set the agent key}" \
  -H 'Content-Type: application/json' \
  --data '{"input":"In one sentence, what does Azure API Management do?"}'
```

## Clean up

Run `scripts/cleanup.sh` with the demo resource group to remove the Azure
gateway, Function, storage, and Static Web App resources in that group.
The Foundry project is external to the demo group. Remove the demo agent and
its agent-scope role assignment separately when they are no longer needed.
