$serviceName = 'Kafka-Connect-Monitoring'
$nssm = (Get-Command nssm).Source
$powershell = (Get-Command powershell).Source
$scriptPath = "$($pwd.Path)\Send-KafkaConnectTaskStatusToLogAnalytics.ps1"
$arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath
& $nssm install $serviceName $powershell $arguments