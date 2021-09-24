# Kafka-Connect Monitoring and Auto-Healing
Monitoring and Auto-Healing Kafka-Connect with PowerShell and Azure Log Analytics

## Requirements
1. [Azure Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace) Workspace
2. [NSSM](https://nssm.cc/) installed
3. Kafka-Connect task running
4. PowerShell (PS Core will run on any platform - windows, linux, mac)

## Usage
1. Clone this repository 
2. Retrieve the Log Analytics Workspace ID and Primary Key from the Azure portal
3. Update the Send-KakfkaConnectTaskStatusToLogAnalytics.ps1 script with the Log Analytics Workspace ID and Primary Key
4. Run the Install-ConnectMonitoringService.ps1 script
5. Start the Kafka-Connect-Monitoring service

After about 10-15 minutes, you should be able to check the Logs area of the Log Analytics workspace and run the following query:

````
KafkaConnect_CL | order by TimeGenerated desc 
````

This will show you the logs sorted by when the log entry was generated (newest to oldest)

With this in place, you can set up email alerts via Log Analytics.  We recommend one alert per connector, with an alert rule similar to:

````
KafkaConnect_CL
| where connector_name_s == "connector-name"
| where state_s  == "RUNNING" 
| where TimeGenerated > ago(10m)
````

With an alert logic of "Number of Results Equal to 0".  This will generate an alert when a connector goes into a failed state, or when data from the task status checks stops coming in.  This should cover all situations.

## Limitations
- The current main limitation is that the status check and auto-healing code expects only a single task per connector.  This limitation could be removed if necessary by altering the Send-KafkaConnectTaskStatusToLogAnalytics.ps1 script to loop through each task.
- In order to run this PowerShell code as a service, a Windows machine is required.  If linux or mac is used, an alternative method of running PowerShell as a service will be necessary.

## Notes on Auto-Healing Functionality
Auto healing is currently handled by detecting a failed task, and then attempting to restart the task via the kafka-connect API.  This will work in some situations (e.g. A souce database goes offline causing a task to fail and then comes back online), but will not work in all situations.  
