# Replace with your Log Analytics Workspace ID
$CustomerId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"  

# Replace with your Log Analytics Primary Key
$SharedKey = ""

# Specify the name of the record type that you'll be creating
$LogType = "KafkaConnect"

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = ""

# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

while($True) {
    #Receive list of Kafka-Connect connectors on the local machine
    $connectors = Invoke-RestMethod -Method GET -Uri "http://localhost:8083/connectors"
    #Initialize allStatuses empty array
    $allStatuses = @()
    #loop through each connector and retrieve the task status
    foreach($connector in $connectors){
        $taskStatus = (Invoke-RestMethod -Method GET -Uri "http://localhost:8083/connectors/$($connector)/status").tasks
        if($taskStatus.state -eq "FAILED"){
            $taskRestartHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $taskRestartHeaders.Add('Accept','application/json')
            $taskRestartHeaders.Add('Content-Type','application/json')
            $restart = Invoke-RestMethod -Method POST -Uri "http://localhost:8083/connectors/$($connector)/tasks/$($taskStatus.id)/restart" -Headers $taskRestartHeaders
            start-sleep 60
            $taskStatus = (Invoke-RestMethod -Method GET -Uri "http://localhost:8083/connectors/$($connector)/status").tasks
        }
        $taskStatus | Add-Member -MemberType NoteProperty -Name "connector_name" -Value $connector
        $allStatuses += $taskStatus
    }

    #convert the result of the task status checks to json and feed that into the $json variable to be sent to log analytics
    $json = $allStatuses | convertto-json

    # Submit the data to the API endpoint
    Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType

    Start-Sleep -Seconds 300
}