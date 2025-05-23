param workspace string

resource workspace_NewBotAddedToTeams 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: '${workspace}/NewBotAddedToTeams'
  location: resourceGroup().location
  properties: {
    eTag: '*'
    displayName: 'Previously unseen bot or application added to Teams'
    category: 'Hunting Queries'
    query: '\nlet starttime = todatetime(\'{{StartTimeISO}}\');\nlet endtime = todatetime(\'{{EndTimeISO}}\');\nlet lookback = starttime - 14d;\nlet historical_bots = (\nOfficeActivity\n| where TimeGenerated between(lookback..starttime)\n| where OfficeWorkload =~ "MicrosoftTeams"\n| where isnotempty(AddonName)\n| project AddonName);\nOfficeActivity\n| where TimeGenerated between(starttime..endtime)\n| where OfficeWorkload =~ "MicrosoftTeams"\n// Look for add-ins we have never seen before\n| where AddonName in (historical_bots)\n| extend timestamp = TimeGenerated, AccountCustomEntity = UserId\n'
    version: 1
    tags: [
      {
        name: 'description'
        value: 'This hunting query helps identify new, and potentially unapproved applications or bots being added to Teams.'
      }
      {
        name: 'tactics'
        value: 'Persistence,Collection'
      }
      {
        name: 'relevantTechniques'
        value: 'T1176,T1119'
      }
    ]
  }
}
