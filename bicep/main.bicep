
@description('Name of the Logic App')
param workflows_appRegistrations_name string = 'appRegistrations'

@description('Deployment location')
param location string = 'northeurope'

@description('External ID for the Key Vault connection')
param connections_keyvault_externalid string

@description('External ID for the ACS Email connection')
param connections_acsemail_externalid string

@description('Notification recipient email')
param notification_email string

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
        Initialize_variable: {
          runAfter: {
            ExpiryThresholdDays: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'ExpiryThresholdDate'
                type: 'string'
                value: '@addDays(utcNow(),variables(\'ExpiryThresholdDays\'))'
              }
            ]
          }
        }
        Debug_variable: {
          runAfter: {
            Initialize_variable: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Debug'
                type: 'string'
              }
            ]
          }
        }
        Get_ClientIDKV: {
          runAfter: {
            Debug_variable: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'ClientIDKV\')}/value'
          }
          runtimeConfiguration: {
            secureData: {
              properties: [
                'inputs'
                'outputs'
              ]
            }
          }
        }
        Get_ClientSecretKV: {
          runAfter: {
            Get_ClientIDKV: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'ClientSecretKV\')}/value'
          }
          runtimeConfiguration: {
            secureData: {
              properties: [
                'inputs'
                'outputs'
              ]
            }
          }
        }
        HTTP: {
          runAfter: {
            Get_ClientSecretKV: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: 'https://graph.microsoft.com/v1.0/applications?$top=999&$select=id,appId,displayName,passwordCredentials,keyCredentials'
            method: 'GET'
            authentication: {
              type: 'ActiveDirectoryOAuth'
              authority: 'https://login.microsoftonline.com/'
              tenant: '91962547-7671-4ed3-bd0b-2edac9992e96'
              audience: 'https://graph.microsoft.com'
              clientId: '@{body(\'Get_ClientIDKV\')?[\'value\']}'
              secret: '@{body(\'Get_ClientSecretKV\')?[\'value\']}'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Parse_JSON: {
          runAfter: {
            HTTP: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'HTTP\')'
            schema: {
              type: 'object'
              properties: {
                body: {
                  type: 'object'
                  properties: {
                    value: {
                      type: 'array'
                      items: {
                        type: 'object'
                        properties: {
                          id: {
                            type: 'string'
                          }
                          appId: {
                            type: 'string'
                          }
                          displayName: {
                            type: 'string'
                          }
                          passwordCredentials: {
                            type: 'array'
                          }
                          keyCredentials: {
                            type: 'array'
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        For_each_apps: {
          foreach: '@coalesce(body(\'Parse_JSON\')?[\'value\'], json(\'[]\'))'
          actions: {
            Parse_JSON_1: {
              type: 'ParseJson'
              inputs: {
                content: '@item()?[\'passwordCredentials\']'
                schema: {
                  type: 'array'
                  items: {
                    type: 'object'
                    properties: {
                      endDateTime: {
                        type: [
                          'string'
                          'null'
                        ]
                        format: 'date-time'
                      }
                      displayName: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      keyId: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                    }
                  }
                }
              }
            }
            Parse_JSON_2: {
              type: 'ParseJson'
              inputs: {
                content: '@item()?[\'keyCredentials\']'
                schema: {
                  type: 'array'
                  items: {
                    type: 'object'
                    properties: {
                      customKeyIdentifier: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      displayName: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      endDateTime: {
                        type: [
                          'string'
                          'null'
                        ]
                        format: 'date-time'
                      }
                      key: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      keyId: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      startDateTime: {
                        type: [
                          'string'
                          'null'
                        ]
                        format: 'date-time'
                      }
                      type: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                      usage: {
                        type: [
                          'string'
                          'null'
                        ]
                      }
                    }
                  }
                }
              }
            }
            For_each_Secret: {
              foreach: '@outputs(\'Parse_JSON_1\')?[\'body\']'
              actions: {
                Set_variable: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'Debug'
                    value: '@items(\'For_each_Secret\')?[\'endDateTime\']'
                  }
                }
                Condition: {
                  actions: {
                    AppendToExpired: {
                      type: 'AppendToArrayVariable'
                      inputs: {
                        name: 'ExpiredApps'
                        value: {
                          'App-Name': '@items(\'For_each_apps\')?[\'displayName\']'
                          AppID: '@items(\'For_each_apps\')?[\'appId\']'
                          ExpiryDate: '@formatDateTime(item()?[\'endDateTime\'], \'yyyy-MM-dd\')'
                          Id: '@items(\'For_each_Secret\')?[\'keyId\']'
                          Owners: ''
                          SecretName: '@items(\'For_each_Secret\')?[\'displayName\']'
                        }
                      }
                    }
                  }
                  runAfter: {
                    Set_variable: [
                      'Succeeded'
                    ]
                  }
                  else: {
                    actions: {}
                  }
                  expression: {
                    and: [
                      {
                        lessOrEquals: [
                          '@items(\'For_each_Secret\')?[\'endDateTime\']'
                          '@variables(\'ExpiryThresholdDate\')'
                        ]
                      }
                      {
                        greaterOrEquals: [
                          '@items(\'For_each_Secret\')?[\'endDateTime\']'
                          '@utcNow()'
                        ]
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              runAfter: {
                Parse_JSON_1: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
            For_each_Key: {
              foreach: '@outputs(\'Parse_JSON_2\')?[\'body\']'
              actions: {
                Set_variable_Key: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'Debug'
                    value: '@items(\'For_each_Key\')?[\'endDateTime\']'
                  }
                }
                Condition_Key: {
                  actions: {
                    AppendToExpired_Key: {
                      type: 'AppendToArrayVariable'
                      inputs: {
                        name: 'ExpiredApps'
                        value: {
                          'App-Name': '@items(\'For_each_apps\')?[\'displayName\']'
                          AppID: '@items(\'For_each_apps\')?[\'appId\']'
                          ExpiryDate: '@formatDateTime(item()?[\'endDateTime\'], \'yyyy-MM-dd\')'
                          Id: '@items(\'For_each_Key\')?[\'keyId\']'
                          Owners: ''
                          SecretName: '@items(\'For_each_Key\')?[\'displayName\']'
                        }
                      }
                    }
                  }
                  runAfter: {
                    Set_variable_Key: [
                      'Succeeded'
                    ]
                  }
                  else: {
                    actions: {}
                  }
                  expression: {
                    and: [
                      {
                        lessOrEquals: [
                          '@items(\'For_each_Key\')?[\'endDateTime\']'
                          '@variables(\'ExpiryThresholdDate\')'
                        ]
                      }
                      {
                        not: [
                          {
                            equals: [
                              '@items(\'For_each_Key\')?[\'endDateTime\']'
                              null
                            ]
                          }
                        ]
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              runAfter: {
                Parse_JSON_2: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
          }
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        Create_HTML_table: {
          runAfter: {
            For_each_apps: [
              'Succeeded'
            ]
          }
          type: 'Table'
          inputs: {
            from: '@variables(\'ExpiredApps\')'
            format: 'HTML'
          }
        }
        Send_email: {
          runAfter: {
            Create_HTML_table: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'acsemail\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: {
              senderAddress: 'DoNotReply@fba3b185-e72b-47fe-a1bb-a2336ae52dd9.azurecomm.net'
              recipients: {
                to: [
                  {
                    address: '@variables(\'EmailRecepient\')'
                  }
                ]
              }
              content: {
                subject: 'Expired Apps'
                html: '<p class="editor-paragraph">This is the list of expired apps.</p><br><p class="editor-paragraph">@{body(\'Create_HTML_table\')}</p>'
              }
              importance: 'Normal'
            }
            path: '/emails:sendGAVersion'
            queries: {
              'api-version': '2023-03-31'
            }
          }
        }
      }
      outputs: {}
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
