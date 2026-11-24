param apimName string
param agentEndpoint string
param siteOrigin string = ''
@minValue(1)
param tokensPerMinute int = 200

resource gateway 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: gateway
  name: 'sc500-agent'
  properties: {
    displayName: 'SC-500 Foundry Agent'
    path: 'agent'
    protocols: ['https']
    serviceUrl: agentEndpoint
    subscriptionRequired: true
  }
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: api
  name: 'responses'
  properties: {
    displayName: 'Call the agent'
    method: 'POST'
    urlTemplate: '/responses'
    responses: [{statusCode: 200}, {statusCode: 429}]
  }
}

resource policy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(loadTextContent('agent-policy.xml'), '__SITE_CORS__', cors), '__TOKENS_PER_MINUTE__', string(tokensPerMinute))
  }
}

var cors = empty(siteOrigin) ? '' : replace(loadTextContent('agent-cors.xml'), '__SITE_ORIGIN__', siteOrigin)

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: gateway
  name: 'sc500-agent-demo'
  dependsOn: [policy, operation]
  properties: {
    displayName: 'SC-500 Agent Demo'
    scope: '/apis/${api.name}'
    state: 'active'
  }
}
