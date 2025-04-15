#define path
$dateString = Get-Date -Format "yyyyMMdd"  # Format: YYYYMMDD
$hostname = hostname  # Get the hostname
$outputFilePath = "C:\temp\dcdiag_report_${hostname}_$dateString.html"    # HTML report output path

# Create or clear the output file
Clear-Content -Path $outputFilePath -ErrorAction SilentlyContinue

# Start the HTML document
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; }
        th { background-color: #f2f2f2; text-align: left; }
        h2 { color: #333; }
    </style>
</head>
<body>

<h1>System Report - Generated on $(Get-Date)</h1>
"@

# Get NTP Sync Status
$htmlContent += "<h2>NTP Sync Status</h2>"
$ntpStatus = w32tm /query /status
$htmlContent += "<pre>$ntpStatus</pre>"

# Get Disk and Volume
$htmlContent += "<h2>Disk & Volume</h2>"
$htmlContent += "<h3>Volumes</h3>"
$htmlContent += "<table><tr><th>Drive Letter</th><th>File System</th><th>Size (GB)</th><th>Free Space (GB)</th></tr>"
Get-Volume | ForEach-Object {
    $htmlContent += "<tr><td>$($_.DriveLetter)</td><td>$($_.FileSystem)</td><td>$([math]::round($_.SizeRemaining/1GB, 2))</td><td>$([math]::round($_.Size/1GB, 2))</td></tr>"
}
$htmlContent += "</table>"

$htmlContent += "<h3>Disks</h3>"
$htmlContent += "<table><tr><th>Disk Number</th><th>Size (GB)</th><th>Status</th><th>Health</th></tr>"
Get-Disk | ForEach-Object {
    $htmlContent += "<tr><td>$($_.Number)</td><td>$([math]::round($_.Size/1GB, 2))</td><td>$($_.OperationalStatus)</td><td>$($_.HealthStatus)</td></tr>"
}
$htmlContent += "</table>"

# Get User Object Count
$htmlContent += "<h2>Total User Object Count</h2>"
$DisabldAccounts = (Search-ADAccount -AccountDisabled).Count
$total = (Get-ADUser -Filter *).Count
$pne = (Get-ADUser -Filter {Enabled -eq $True -and PasswordNeverExpires -eq $True}).Count
$enabled = (Get-ADUser -Filter {Enabled -eq $True}).Count

$htmlContent += "<table>
    <tr><th>Description</th><th>Count</th></tr>
    <tr><td>Password Never Expires ON</td><td>$pne</td></tr>
    <tr><td>Disabled User Objects</td><td>$DisabldAccounts</td></tr>
    <tr><td>Enabled User Objects</td><td>$enabled</td></tr>
    <tr><td>Total User Objects</td><td>$total</td></tr>
</table>"

# Get Top 5 Errors for DC
$htmlContent += "<h2>Top 5 Errors</h2>"
$Servers = $env:computername

$Logs = Get-EventLog -LogName System -EntryType Error -ComputerName $Servers |
    Group-Object -Property MachineName

$Results = foreach ($Log in $Logs) {
    $Server = $Log.Name
    $TopFive = $Log.Group |
        Group-Object -Property Source, EventID |
        Sort-Object -Property Count -Descending |
        Select-Object -First 5

    foreach ($Event in $TopFive) {
        New-Object -TypeName psobject -Property @{
            Server  = $Server
            Source  = $Event.Name.Split(',')[0].Trim()
            EventID = $Event.Name.Split(',')[1].Trim()
            Count   = $Event.Count
            Message = $Event.Group | Select-Object -First 1 -ExpandProperty Message
        }
    }
}

# Create a table for errors
$htmlContent += "<table><tr><th>Server</th><th>Source</th><th>Event ID</th><th>Count</th><th>Message</th></tr>"
$Results | Select-Object -Property Server, Source, EventID, Count, Message | ForEach-Object {
    $htmlContent += "<tr><td>$($_.Server)</td><td>$($_.Source)</td><td>$($_.EventID)</td><td>$($_.Count)</td><td>$($_.Message)</td></tr>"
}
$htmlContent += "</table>"

# Last Boot within last 90 days
$htmlContent += "<h2>Recent Reboots (Last 90 Days)</h2>"
$recentReboots = Get-WinEvent -ComputerName $env:COMPUTERNAME -FilterHashtable @{
    Logname = 'system'
    Id = '1074', '6008'
    StartTime = (Get-Date).AddDays(-90)
} -MaxEvents 10 | Select-Object -Property TimeCreated, Message

$htmlContent += "<table><tr><th>Date & Time</th><th>Message</th></tr>"
$recentReboots | ForEach-Object {
    $htmlContent += "<tr><td>$($_.TimeCreated)</td><td>$($_.Message)</td></tr>"
}
$htmlContent += "</table>"

# End the HTML document
$htmlContent += @"
</body>
</html>
"@

# Write the HTML content to the file
$htmlContent | Out-File -FilePath $outputFilePath -Encoding UTF8

Write-Host "Report generated at $outputFilePath"
