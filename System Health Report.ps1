# Get the hostname
$hostname = $env:COMPUTERNAME

# Define the output file path
$htmlOutputFile = "C:\temp\SystemHealthCheck_$hostname_$(Get-Date -Format 'yyyyMMdd').html"

# Function to capture disk and volume information
function Get-DiskInfo {
    Get-PSDrive -PSProvider FileSystem | Select-Object Name, 
        @{Name="TotalSizeGB"; Expression={[math]::Round(($_.Used + $_.Free) / 1GB, 1)}}, 
        @{Name="UsedSpaceGB"; Expression={[math]::Round($_.Used / 1GB, 1)}}, 
        @{Name="FreeSpaceGB"; Expression={[math]::Round($_.Free / 1GB, 1)}}
}

# Function to get local accounts and their enabled/disabled status
function Get-LocalAccountsStatus {
    Get-LocalUser | Select-Object Name, Enabled
}

# Function to get active file shares
function Get-ActiveShares {
    Get-SmbShare | Select-Object Name, Path, Description
}

# Function to get network configuration details
function Get-NetworkInfo {
    Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' } | Select-Object InterfaceAlias, IPAddress, PrefixLength
}

# Function to get top 5 processes consuming the most CPU
function Get-TopCPUProcesses {
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, @{Name="CPU"; Expression={[math]::Round($_.CPU, 2)}}, Id
}

# Function to get top 5 processes consuming the most Memory
function Get-TopMemoryProcesses {
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 Name, @{Name="MemoryMB"; Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}}, Id
}

# Function to get the top 5 repeated Application event logs
function Get-TopApplicationLogs {
    Get-EventLog -LogName Application -EntryType Error -Newest 1000 | Group-Object Message | Sort-Object Count -Descending | Select-Object -First 5 Name, Count
}

# Function to get the top 5 repeated System event logs
function Get-TopSystemLogs {
    Get-EventLog -LogName System -EntryType Error -Newest 1000 | Group-Object Message | Sort-Object Count -Descending | Select-Object -First 5 Name, Count
}

# Sanitize JavaScript strings
function Sanitize-ForJavaScript {
    param ([string]$input)
    return $input -replace '"', '\"'
}

# Create an HTML report with Tables
function Generate-HTMLReport {
    param (
        [string]$HtmlFile
    )

    # Get all required data
    $diskInfo = Get-DiskInfo
    $accounts = Get-LocalAccountsStatus
    $shares = Get-ActiveShares
    $network = Get-NetworkInfo
    $topCPU = Get-TopCPUProcesses
    $topMemory = Get-TopMemoryProcesses
    $appLogs = Get-TopApplicationLogs
    $sysLogs = Get-TopSystemLogs

    # Prepare Data for Tables
    $diskNames = ($diskInfo | ForEach-Object { $_.Name }) -join '","'
    $diskTotalSize = ($diskInfo | ForEach-Object { $_.TotalSizeGB }) -join ','
    $diskUsed = ($diskInfo | ForEach-Object { $_.UsedSpaceGB }) -join ','
    $diskFree = ($diskInfo | ForEach-Object { $_.FreeSpaceGB }) -join ','

    $topCPUProcesses = ($topCPU | ForEach-Object { Sanitize-ForJavaScript $_.Name }) -join '","'
    $topCPUTimes = ($topCPU | ForEach-Object { $_.CPU }) -join ','

    $topMemoryProcesses = ($topMemory | ForEach-Object { Sanitize-ForJavaScript $_.Name }) -join '","'
    $topMemoryUsage = ($topMemory | ForEach-Object { $_.MemoryMB }) -join ','

    # Initialize HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Health Check - $hostname</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #004085; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .chart-container { width: 600px; height: 400px; margin: 20px auto; }
    </style>
</head>
<body>
    <h1>System Health Check Report - $hostname - $(Get-Date -Format 'yyyy-MM-dd')</h1>

    <h2>Top 5 CPU Consuming Processes</h2>
    <table><tr><th>Name</th><th>CPU Time</th><th>Process ID</th></tr>
"@

    foreach ($cpu in $topCPU) {
        $htmlContent += "<tr><td>$($cpu.Name)</td><td>$($cpu.CPU)</td><td>$($cpu.Id)</td></tr>"
    }
    $htmlContent += "</table>"

    $htmlContent += @"
    <h2>Top 5 Memory Consuming Processes</h2>
    <table><tr><th>Name</th><th>Memory (MB)</th><th>Process ID</th></tr>
"@

    foreach ($mem in $topMemory) {
        $htmlContent += "<tr><td>$($mem.Name)</td><td>$($mem.MemoryMB)</td><td>$($mem.Id)</td></tr>"
    }
    $htmlContent += "</table>"

    $htmlContent += @"
    <h2>Disks and Volumes</h2><table><tr><th>Name</th><th>Total Size (GB)</th><th>Used Space (GB)</th><th>Free Space (GB)</th></tr>
"@

    foreach ($disk in $diskInfo) {
        $htmlContent += "<tr><td>$($disk.Name)</td><td>$($disk.TotalSizeGB)</td><td>$($disk.UsedSpaceGB)</td><td>$($disk.FreeSpaceGB)</td></tr>"
    }
    $htmlContent += "</table>"

    # Local Accounts
    $htmlContent += "<h2>Local Accounts</h2><table><tr><th>Name</th><th>Enabled</th></tr>"
    foreach ($account in $accounts) {
        $htmlContent += "<tr><td>$($account.Name)</td><td>$($account.Enabled)</td></tr>"
    }
    $htmlContent += "</table>"

    # Active Shares
    $htmlContent += "<h2>Active File Shares</h2><table><tr><th>Name</th><th>Path</th><th>Description</th></tr>"
    foreach ($share in $shares) {
        $htmlContent += "<tr><td>$($share.Name)</td><td>$($share.Path)</td><td>$($share.Description)</td></tr>"
    }
    $htmlContent += "</table>"

    # Network Information
    $htmlContent += "<h2>Network Information</h2><table><tr><th>Interface Alias</th><th>IP Address</th><th>Prefix Length</th></tr>"
    foreach ($net in $network) {
        $htmlContent += "<tr><td>$($net.InterfaceAlias)</td><td>$($net.IPAddress)</td><td>$($net.PrefixLength)</td></tr>"
    }
    $htmlContent += "</table>"

    # Top Application Event Logs
    $htmlContent += "<h2>Top 5 Most Repeated Application Event Logs</h2><table><tr><th>Event</th><th>Count</th></tr>"
    foreach ($appLog in $appLogs) {
        $htmlContent += "<tr><td>$($appLog.Name)</td><td>$($appLog.Count)</td></tr>"
    }
    $htmlContent += "</table>"

    # Top System Event Logs
    $htmlContent += "<h2>Top 5 Most Repeated System Event Logs</h2><table><tr><th>Event</th><th>Count</th></tr>"
    foreach ($sysLog in $sysLogs) {
        $htmlContent += "<tr><td>$($sysLog.Name)</td><td>$($sysLog.Count)</td></tr>"
    }
    $htmlContent += "</table>"

    $htmlContent += "</body></html>"

    # Write to the output HTML file
    Set-Content -Path $HtmlFile -Value $htmlContent
}

# Generate the system health check report
Write-Host "Generating System Health Check Report..."
Generate-HTMLReport -HtmlFile $htmlOutputFile

Write-Host "System Health Check Report generated successfully at $htmlOutputFile."
