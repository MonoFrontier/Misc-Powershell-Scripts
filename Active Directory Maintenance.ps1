#Requires -RunAsAdministrator
#Requires -Module ActiveDirectory

# Set up logging and report output
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "C:\DC_Maintenance_Logs"
$reportDir = "$logDir\Reports"
$logFile = "$logDir\Maintenance_$timestamp.log"
$htmlFile = "$reportDir\DC_Maintenance_Report_$timestamp.html"
$pdfFile = "$reportDir\DC_Maintenance_Report_$timestamp.pdf"

# Create directories if they don’t exist
foreach ($dir in $logDir, $reportDir) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Function to write to log
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Host "$timestamp - $Message"
}

# Start script
Write-Log "Starting Domain Controller Maintenance Check"

# HTML report header
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Domain Controller Maintenance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { text-align: center; }
        h2 { color: #2E86C1; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        ul { list-style-type: disc; margin-left: 20px; }
        .chart { font-family: monospace; white-space: pre; }
    </style>
</head>
<body>
    <h1>Domain Controller Maintenance Report</h1>
    <p style='text-align: center;'>Generated on: $(Get-Date)</p>
"@

# 1. Timezone and System Time (List)
$htmlContent += "<h2>Timezone and System Time</h2><ul>"
$timezone = Get-TimeZone
$timeSync = (w32tm /query /status) -join "<br>"
$htmlContent += "<li>Timezone: $($timezone.Id)</li>"
$htmlContent += "<li>Current Time: $(Get-Date)</li>"
$htmlContent += "<li>Time Synchronization Status: $timeSync</li>"
$htmlContent += "</ul>"

# 2. System Health (List)
$htmlContent += "<h2>System Health</h2><ul>"
$osInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber
$htmlContent += "<li>OS Name: $($osInfo.WindowsProductName)</li>"
$htmlContent += "<li>OS Version: $($osInfo.WindowsVersion)</li>"
$htmlContent += "<li>Build Number: $($osInfo.OsBuildNumber)</li>"
$htmlContent += "</ul>"

# 3. Hardware Information (Text-based Charts)
$htmlContent += "<h2>Hardware Information</h2>"
$cpu = Get-WmiObject -Class Win32_Processor | Select-Object Name, NumberOfCores
$totalRAM = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$disks = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | Select-Object DriveLetter, FileSystemLabel, @{Name='SizeGB';Expression={[math]::Round($_.Size / 1GB, 2)}}, @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

$htmlContent += "<p>CPU: $($cpu.Name), Cores: $($cpu.NumberOfCores)</p>"
$htmlContent += "<div class='chart'>RAM: [$([string]'█' * [int]$totalRAM)] $totalRAM GB</div>"
foreach ($disk in $disks) {
    $usedGB = $disk.SizeGB - $disk.FreeGB
    $htmlContent += "<div class='chart'>Disk $($disk.DriveLetter): [$([string]'█' * [int]$usedGB)] Used: $usedGB GB, Free: $($disk.FreeGB) GB</div>"
}

# 4. Volumes and Shares (Table)
$htmlContent += "<h2>Volumes and Shares</h2>"
$volumes = Get-Volume | Select-Object DriveLetter, FileSystemLabel
$htmlContent += "<table><tr><th>Drive Letter</th><th>Label</th></tr>"
foreach ($vol in $volumes) {
    $htmlContent += "<tr><td>$($vol.DriveLetter)</td><td>$($vol.FileSystemLabel)</td></tr>"
}
$htmlContent += "</table>"

$shares = Get-SmbShare | Select-Object Name, Path
$htmlContent += "<table><tr><th>Share Name</th><th>Path</th></tr>"
foreach ($share in $shares) {
    $htmlContent += "<tr><td>$($share.Name)</td><td>$($share.Path)</td></tr>"
}
$htmlContent += "</table>"

# 5. Roles and Features (List)
$htmlContent += "<h2>Installed Roles and Features</h2><ul>"
$features = Get-WindowsFeature | Where-Object { $_.Installed } | Select-Object -ExpandProperty Name
foreach ($feature in $features) {
    $htmlContent += "<li>$feature</li>"
}
$htmlContent += "</ul>"

# 6. Active Directory and Dependent Services (List)
$htmlContent += "<h2>AD and Dependent Services</h2><ul>"
$services = Get-Service -Name NTDS, DNS, Kdc, Netlogon, DFSR | Select-Object Name, Status
foreach ($service in $services) {
    $htmlContent += "<li>Service: $($service.Name) - Status: $($service.Status)</li>"
}
$htmlContent += "</ul>"

# 7. Domain Controller Role (Table)
$htmlContent += "<h2>Domain Controller Role</h2>"
$dcInfo = Get-ADDomainController | Select-Object Name, Site
$htmlContent += "<table><tr><th>Name</th><th>Site</th></tr>"
$htmlContent += "<tr><td>$($dcInfo.Name)</td><td>$($dcInfo.Site)</td></tr>"
$htmlContent += "</table>"

# 8. FSMO Roles (List)
$htmlContent += "<h2>FSMO Roles</h2><ul>"
$domainFSMO = Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator
$forestFSMO = Get-ADForest | Select-Object DomainNamingMaster, SchemaMaster
$htmlContent += "<li>Domain FSMO - Infra: $($domainFSMO.InfrastructureMaster), RID: $($domainFSMO.RIDMaster), PDC: $($domainFSMO.PDCEmulator)</li>"
$htmlContent += "<li>Forest FSMO - DomainNaming: $($forestFSMO.DomainNamingMaster), Schema: $($forestFSMO.SchemaMaster)</li>"
$htmlContent += "</ul>"

# 9. Domain Controller Sites (Table)
$htmlContent += "<h2>Domain Controller Sites</h2>"
$sites = Get-ADDomainController -Filter * | Select-Object Name, Site
$htmlContent += "<table><tr><th>Name</th><th>Site</th></tr>"
foreach ($site in $sites) {
    $htmlContent += "<tr><td>$($site.Name)</td><td>$($site.Site)</td></tr>"
}
$htmlContent += "</table>"

# 10. Domain Recycle Bin (List)
$htmlContent += "<h2>Domain Recycle Bin</h2><ul>"
$recycleBin = Get-ADOptionalFeature -Filter 'Name -eq "Recycle Bin Feature"' | Select-Object -ExpandProperty EnabledScopes
$htmlContent += "<li>Recycle Bin Enabled: $(if ($recycleBin) { 'Yes' } else { 'No' })</li>"
$htmlContent += "</ul>"

# 11. DNS Tests (List)
$htmlContent += "<h2>DNS Tests</h2><ul>"
$internalDNS = Resolve-DnsName -Name (Get-ADDomain).DNSRoot -ErrorAction SilentlyContinue
$externalDNS = Test-NetConnection -ComputerName one.one.one.one -Port 53
$htmlContent += "<li>Internal DNS Test: $(if ($internalDNS) { 'Success' } else { 'Failed' })</li>"
$htmlContent += "<li>External DNS Test (Cloudflare 1.1.1.1): $($externalDNS.TcpTestSucceeded)</li>"
$htmlContent += "</ul>"

# 12. Secondary Domain Controller (Table)
$htmlContent += "<h2>Secondary Domain Controller</h2>"
$dcs = Get-ADDomainController -Filter * | Where-Object { $_.HostName -ne $env:COMPUTERNAME }
if ($dcs) {
    $htmlContent += "<table><tr><th>HostName</th><th>Ping</th><th>DNS</th></tr>"
    foreach ($dc in $dcs) {
        $ping = Test-Connection -ComputerName $dc.HostName -Count 1 -Quiet
        $dnsResolve = [bool](Resolve-DnsName -Name $dc.HostName -ErrorAction SilentlyContinue)
        $htmlContent += "<tr><td>$($dc.HostName)</td><td>$(if ($ping) { 'Reachable' } else { 'Unreachable' })</td><td>$(if ($dnsResolve) { 'Resolves' } else { 'Does not resolve' })</td></tr>"
    }
    $htmlContent += "</table>"
} else {
    $htmlContent += "<p>No secondary Domain Controller found</p>"
}

# 14. Latest Windows Updates (Table)
$htmlContent += "<h2>Latest Windows Updates (Last 30 Days)</h2>"
$updates = Get-HotFix | Where-Object { $_.InstalledOn -ge (Get-Date).AddMonths(-1) } | Select-Object Description, HotFixID, InstalledOn
if ($updates) {
    $htmlContent += "<table><tr><th>Description</th><th>HotFixID</th><th>Installed On</th></tr>"
    foreach ($update in $updates) {
        $htmlContent += "<tr><td>$($update.Description)</td><td>$($update.HotFixID)</td><td>$($update.InstalledOn)</td></tr>"
    }
    $htmlContent += "</table>"
} else {
    $htmlContent += "<p>No updates found in the last month</p>"
}

# 15. Top Repeating Windows Events (Table)
$htmlContent += "<h2>Top Repeating Windows Events (Last 30 Days)</h2>"
$events = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue | 
          Group-Object -Property Id | Sort-Object -Property Count -Descending | Select-Object -First 10 | 
          Select-Object Count, @{Name='EventID';Expression={$_.Name}}, @{Name='Message';Expression={($_.Group | Select-Object -First 1).Message}}
$htmlContent += "<table><tr><th>Count</th><th>Event ID</th><th>Message</th></tr>"
foreach ($event in $events) {
    $htmlContent += "<tr><td>$($event.Count)</td><td>$($event.EventID)</td><td>$($event.Message)</td></tr>"
}
$htmlContent += "</table>"

# Close HTML
$htmlContent += "</body></html>"

# Save the HTML report
$htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8
Write-Log "HTML Report generated at: $htmlFile"

# Optional: Convert to PDF (requires wkhtmltopdf or similar tool)
# Example (uncomment and adjust path if installed):
# & "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe" $htmlFile $pdfFile
# Write-Log "PDF Report generated at: $pdfFile"

# End script
Write-Log "Domain Controller Maintenance Check Completed"
