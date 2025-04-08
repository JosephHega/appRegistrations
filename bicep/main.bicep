
@description('Deployment location')
param location string

@description('Notification recipient email')
param notification_email string

@description('Azure Tenant ID')
param azureTenantId string

param workflows_appRegistrations_name string = 'appRegistrations'
param connections_keyvault_externalid string = '/subscriptions/fb4e727e-f4b0-42b0-8950-8a4961a2bce9/resourceGroups/LogicApp-RG/providers/Microsoft.Web/connections/keyvault'
param connections_acsemail_externalid string = '/subscriptions/fb4e727e-f4b0-42b0-8950-8a4961a2bce9/resourceGroups/LogicApp-RG/providers/Microsoft.Web/connections/acsemail'

resource workflows_appRegistrations_name_resource 'Microsoft.Logic/workflows@2017-07-01' = {
  name: workflows_appRegistrations_name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            interval: 14
            frequency: 'Day'
          }
          evaluatedRecurrence: {
            interval: 14
            frequency: 'Day'
          }
          type: 'Recurrence'
        }
      }
      actions: {
        ExpiredApps: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'ExpiredApps'
                type: 'array'
              }
            ]
          }
        }
        EmailRecepient: {
          runAfter: {
            ExpiredApps: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailRecepient'
                type: 'string'
                value: notification_email
              }
            ]
          }
        }
        ExpiryThresholdDays: {
          runAfter: {
            EmailRecepient: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'ExpiryThresholdDays'
                type: 'integer'
                value: 15
              }
            ]
          }
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          keyvault: {
            id: '/subscriptions/fb4e727e-f4b0-42b0-8950-8a4961a2bce9/providers/Microsoft.Web/locations/northeurope/managedApis/keyvault'
            connectionId: connections_keyvault_externalid
            connectionName: 'keyvault'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
          acsemail: {
            id: '/subscriptions/fb4e727e-f4b0-42b0-8950-8a4961a2bce9/providers/Microsoft.Web/locations/northeurope/managedApis/acsemail'
            connectionId: connections_acsemail_externalid
            connectionName: 'acsemail'
          }
        }
      }
    }
  }
}
