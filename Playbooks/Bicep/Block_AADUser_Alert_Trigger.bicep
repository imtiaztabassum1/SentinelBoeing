metadata title = 'Block AAD user - Alert'
metadata description = 'For each account entity included in the alert, this playbook will disable the user in Azure Active Directoy and add a comment to the incident that contains this alert'
metadata prerequisites = ''
metadata lastUpdateTime = '2021-07-14T00:00:00.000Z'
metadata entities = [
  'Account'
]
metadata tags = [
  'Remediation'
]
metadata support = {
  tier: 'community'
}
metadata author = {
  name: 'Nicholas DiCola'
}

param PlaybookName string = 'Block-AADUser-Alert'
param workspace string

var AzureADConnectionName = 'azuread-${PlaybookName}'
var AzureSentinelConnectionName = 'azuresentinel-${PlaybookName}'

resource AzureADConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: AzureADConnectionName
  location: resourceGroup().location
  properties: {
    displayName: AzureADConnectionName
    customParameterValues: {}
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuread'
    }
  }
}

resource AzureSentinelConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: AzureSentinelConnectionName
  location: resourceGroup().location
  kind: 'V1'
  properties: {
    displayName: AzureSentinelConnectionName
    customParameterValues: {}
    parameterValueType: 'Alternative'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuresentinel'
    }
  }
}

resource Playbook 'Microsoft.Logic/workflows@2017-07-01' = {
  name: PlaybookName
  location: resourceGroup().location
  tags: {
    LogicAppsCategory: 'security'
    'hidden-SentinelTemplateName': 'Block-AADUser_alert'
    'hidden-SentinelTemplateVersion': '1.0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      actions: {
        'Alert_-_Get_incident': {
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/Incidents/subscriptions/@{encodeURIComponent(triggerBody()?[\'WorkspaceSubscriptionId\'])}/resourceGroups/@{encodeURIComponent(triggerBody()?[\'WorkspaceResourceGroup\'])}/workspaces/@{encodeURIComponent(triggerBody()?[\'WorkspaceId\'])}/alerts/@{encodeURIComponent(triggerBody()?[\'SystemAlertId\'])}'
          }
          runAfter: {}
          type: 'ApiConnection'
        }
        'Entities_-_Get_Accounts': {
          inputs: {
            body: '@triggerBody()?[\'Entities\']'
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/entities/account'
          }
          runAfter: {
            'Alert_-_Get_incident': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
        }
        For_each: {
          actions: {
            Condition: {
              actions: {
                'Add_comment_to_incident_(V3)': {
                  inputs: {
                    body: {
                      incidentArmId: '@body(\'Alert_-_Get_incident\')?[\'id\']'
                      message: '<p>User was disabled in AAD via playbook</p>'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/Incidents/Comment'
                  }
                  runAfter: {}
                  type: 'ApiConnection'
                }
              }
              else: {
                actions: {
                  'Add_comment_to_incident_(V3)_2': {
                    inputs: {
                      body: {
                        incidentArmId: '@body(\'Alert_-_Get_incident\')?[\'id\']'
                        message: '<p>@{body(\'Update_user\')[\'error\'][\'message\']}</p>'
                      }
                      host: {
                        connection: {
                          name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                        }
                      }
                      method: 'post'
                      path: '/Incidents/Comment'
                    }
                    runAfter: {}
                    type: 'ApiConnection'
                  }
                }
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@body(\'Update_user\')'
                      null
                    ]
                  }
                ]
              }
              runAfter: {
                Update_user: [
                  'Succeeded'
                  'Failed'
                ]
              }
              type: 'If'
            }
            Update_user: {
              inputs: {
                body: {
                  accountEnabled: false
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azuread\'][\'connectionId\']'
                  }
                }
                method: 'patch'
                path: '/v1.0/users/@{encodeURIComponent(concat(items(\'For_each\')?[\'Name\'], \'@\', items(\'for_each\')?[\'UPNSuffix\']))}'
              }
              runAfter: {}
              type: 'ApiConnection'
            }
          }
          foreach: '@body(\'Entities_-_Get_Accounts\')?[\'Accounts\']'
          runAfter: {
            'Entities_-_Get_Accounts': [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
      }
      contentVersion: '1.0.0.0'
      outputs: {}
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_a_response_to_an_Azure_Sentinel_alert_is_triggered: {
          inputs: {
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            path: '/subscribe'
          }
          type: 'ApiConnectionWebhook'
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          azuread: {
            connectionId: AzureADConnection.id
            connectionName: AzureADConnectionName
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuread'
          }
          azuresentinel: {
            connectionId: AzureSentinelConnection.id
            connectionName: AzureSentinelConnectionName
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuresentinel'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
  }
}
