targetScope = 'resourceGroup'

@description('SRE Agent resource name')
param agentName string

@description('Azure region for the SRE Agent resource')
param location string = 'australiaeast'

@description('User-assigned managed identity name for the agent')
param userAssignedIdentityName string = '${agentName}-uai'

@description('Application Insights resource name used for agent telemetry')
param appInsightsName string = 'ai-zava77ac'

@description('The Entra object ID of the user who should administer the SRE Agent resource')
param userObjectId string

@description('Model provider for the SRE Agent')
param defaultModelProvider string = 'Anthropic'

@description('Agent action access level')
@allowed([
  'Low'
  'Medium'
  'High'
])
param accessLevel string = 'Low'

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: userAssignedIdentityName
  location: location
  properties: {
    isolationScope: 'Regional'
  }
}

resource agent 'Microsoft.App/agents@2025-05-01-preview' = {
  name: agentName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${agentIdentity.id}': {}
    }
  }
  properties: {
    knowledgeGraphConfiguration: {
      managedResources: [
        resourceGroup().id
      ]
      identity: agentIdentity.id
    }
    actionConfiguration: {
      mode: 'review'
      identity: agentIdentity.id
      accessLevel: accessLevel
    }
    incidentManagementConfiguration: {
      apiConnectionName: null
      connectionKey: ''
      connectionName: 'azmonitor'
      connectionUrl: null
      oboUser: null
      type: 'AzMonitor'
    }
    mcpServers: []
    logConfiguration: {
      applicationInsightsConfiguration: {
        appId: appInsights.properties.AppId
        connectionString: appInsights.properties.ConnectionString
        applicationInsightsResourceId: appInsights.id
      }
    }
    defaultModel: {
      provider: defaultModelProvider
      name: 'Automatic'
    }
    experimentalSettings: {
      EnableV2AgentLoop: true
      EnableWorkspaceTools: true
    }
  }
}

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var monitoringReaderRoleId = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
var logAnalyticsReaderRoleId = '73c42c96-874c-492b-b04d-ab87d138a893'
var azureMonitorContributorRoleId = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
var sreAgentUserRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

resource rgReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, agentName, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource rgMonitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, agentName, monitoringReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleId)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource rgLogAnalyticsReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, agentName, logAnalyticsReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReaderRoleId)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource rgAzureMonitorContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, agentName, azureMonitorContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureMonitorContributorRoleId)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource agentUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agent.id, userObjectId, sreAgentUserRoleId)
  scope: agent
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sreAgentUserRoleId)
    principalId: userObjectId
    principalType: 'User'
  }
}

output agentEndpoint string = agent.properties.agentEndpoint
output agentId string = agent.id
output userAssignedIdentityId string = agentIdentity.id
