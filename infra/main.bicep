@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Globally unique, lowercase prefix of 3-16 alphanumeric characters.')
@minLength(3)
@maxLength(16)
param resourcePrefix string

@description('Optional HTTPS origin of the interactive demo page.')
param siteOrigin string = ''

var functionAppName = '${resourcePrefix}-func'
var storageAccountName = toLower(replace('${resourcePrefix}store', '-', ''))
var apimName = '${resourcePrefix}-apim'
var planName = '${resourcePrefix}-plan'
var apiName = 'hello-api'
var productId = 'hello-product'
var subscriptionId = 'demo-subscription'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'linux'
  properties: { reserved: true }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
      ]
    }
  }
}

resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'replace-before-production@example.com'
    publisherName: 'Azure APIM Function Demo'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: 'Function hello API'
    path: 'hello'
    protocols: [ 'https' ]
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

resource browserPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = if (!empty(siteOrigin)) {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('hello-cors.xml'), '__SITE_ORIGIN__', siteOrigin)
  }
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: api
  name: 'get-hello'
  properties: {
    displayName: 'Get greeting'
    method: 'GET'
    urlTemplate: '/hello'
    responses: [{
      statusCode: 200
      description: 'Greeting returned'
    }]
  }
}

resource product 'Microsoft.ApiManagement/service/products@2022-08-01' = {
  parent: apim
  name: productId
  properties: {
    displayName: 'Hello demo product'
    description: 'Subscription-protected APIM demonstration API.'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2022-08-01' = {
  parent: product
  name: api.name
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: apim
  name: subscriptionId
  properties: {
    displayName: 'Demo test subscription'
    scope: '/products/${productId}'
    state: 'active'
    allowTracing: false
  }
}

output functionAppName string = functionApp.name
output functionUrl string = 'https://${functionApp.properties.defaultHostName}/api/hello'
output apimName string = apim.name
output apimUrl string = 'https://${apim.name}.azure-api.net/hello/hello'
output subscriptionId string = subscription.name
