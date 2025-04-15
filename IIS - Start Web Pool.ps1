# Get the web application pool state
$appPoolState = Get-WebAppPoolState -Name $appPoolName

# Check if the application pool is stopped and start it if needed
if ($appPoolState.Value -eq "Stopped") {
    Write-Host "Application pool '$appPoolName' is in a stopped state. Starting the application pool..."
    Start-WebAppPool -Name $appPoolName
    Write-Host "Application pool '$appPoolName' has been started."
} elseif ($appPoolState.Value -eq "Started") {
    Write-Host "Application pool '$appPoolName' is already in a started state."
} else {
    Write-Host "Failed to determine the state of application pool '$appPoolName'."
}
