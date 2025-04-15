# Function to prompt user for input and capture event logs, then output to HTML
function Get-EventLogsToHTML {
    # Prompt the user to enter the log name (e.g., Application, System, Security)
    $logName = Read-Host "Enter the Windows Event Log Name (e.g., Application, System, Security)"

    # Prompt the user to enter the Event ID
    $eventID = Read-Host "Enter the Event ID you want to search for"

    # Validate inputs
    if (-not $logName -or -not $eventID) {
        Write-Host "Invalid input. Please provide both Log Name and Event ID."
        return
    }

    # Retrieve the event logs based on user input
    try {
        $events = Get-EventLog -LogName $logName -InstanceId $eventID -Newest 20

        if ($events) {
            Write-Host "`nFound $($events.Count) events for Log: $logName and Event ID: $eventID"
            
            # Generate HTML content
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Event Logs for $logName - Event ID $eventID</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #004085; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>Event Logs for $logName - Event ID $eventID</h1>
    <table>
        <tr>
            <th>Time Generated</th>
            <th>Entry Type</th>
            <th>Source</th>
            <th>Event ID</th>
            <th>Message</th>
        </tr>
"@

            foreach ($event in $events) {
                $htmlContent += "<tr>
                    <td>$($event.TimeGenerated)</td>
                    <td>$($event.EntryType)</td>
                    <td>$($event.Source)</td>
                    <td>$($event.EventID)</td>
                    <td>$($event.Message -replace "`n", "<br>")</td>
                </tr>"
            }

            $htmlContent += @"
    </table>
</body>
</html>
"@

            # Display results and save to HTML
            Write-Host "Results formatted. Displaying output..."

            # Prompt user to save the results to an HTML file
            $saveToFile = Read-Host "`nWould you like to save the results to an HTML file? (y/n)"
            if ($saveToFile -eq "y") {
                $filePath = "C:\temp\EventLogs_${logName}_${eventID}_$(Get-Date -Format 'yyyyMMdd').html"
                $htmlContent | Out-File -FilePath $filePath -Encoding utf8
                Write-Host "Results saved to $filePath"
            }
        } else {
            Write-Host "`nNo events found for Log: $logName and Event ID: $eventID"
        }

    } catch {
        Write-Host "An error occurred: $_"
    }
}

# Run the function
Get-EventLogsToHTML
