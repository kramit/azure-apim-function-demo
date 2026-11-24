param apimName string
param publisherEmail string
param location string = resourceGroup().location

resource gateway 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  identity: { type: 'SystemAssigned' }
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherName: 'SC-500 API Demo'
    publisherEmail: publisherEmail
  }
}
output principalId string = gateway.identity.principalId
