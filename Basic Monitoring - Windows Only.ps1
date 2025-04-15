# CPU Temperature in Celsius
try {
    $temp = Get-WmiObject -Class MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
    $currentTempCelsius = foreach ($sensor in $temp) {
        $kelvin = $sensor.CurrentTemperature / 10
        [math]::Round($kelvin - 273.15, 2)
    }
    $currentTempCelsius = $currentTempCelsius -join ", "
} catch {
    $currentTempCelsius = "Not Available"
}

# Disk I/O Rate in MBps (using CIM as fallback if Get-Counter fails)
try {
    Import-Module Microsoft.PowerShell.Diagnostics -ErrorAction SilentlyContinue
    $diskIoSample = Get-Counter -Counter "\LogicalDisk(_Total)\Disk Bytes/sec" -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
    $diskIoRateBytesPerSec = $diskIoSample.CounterSamples.CookedValue
    $diskIoRateMBps = [math]::Round($diskIoRateBytesPerSec / 1048576, 2)
} catch {
    try {
        $diskData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_LogicalDisk -Filter "Name = '_Total'" -ErrorAction Stop
        $diskIoRateMBps = [math]::Round(($diskData.DiskBytesPersec) / 1048576, 2)
    } catch {
        $diskIoRateMBps = "Not Available"
    }
}

# Fan Status
try {
    $fans = Get-CimInstance -ClassName Win32_Fan -ErrorAction Stop
    if ($fans) {
        $systemCooling = $fans | ForEach-Object { "$($_.DeviceID) - Status: $($_.Status), ActiveCooling: $($_.ActiveCooling)" } | Out-String
    } else {
        $systemCooling = "No fans detected"
    }
} catch {
    $systemCooling = "Not Available"
}

# Power Status (Battery for laptops, PSU for desktops)
if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop
        $batteryStatus = "Current Capacity: $($battery.EstimatedChargeRemaining)%"
        $batteryStatus += switch ($battery.BatteryStatus) {
            1 { ", Charging" }
            2 { ", Discharging" }
            3 { ", Fully Charged" }
            default { ", Unknown status" }
        }
    } catch {
        $batteryStatus = "Not Available"
    }
    $psuStatus = $null
} else {
    try {
        Import-Module Microsoft.PowerShell.Diagnostics -ErrorAction SilentlyContinue
        $psuPowerWatts = (Get-Counter -Counter "\Power Meter\Power (Watts)" -ErrorAction Stop).CounterSamples.CookedValue
        $psuStatus = "Power consumption: $psuPowerWatts Watts"
    } catch {
        $psuStatus = "Connected to AC power"
    }
    $batteryStatus = $null
}

# Output Results
Write-Output "CPU Temperature: $currentTempCelsius °C"
Write-Output "Disk I/O Rate: $diskIoRateMBps MBps"
Write-Output "Fan Status:`n$systemCooling"
if ($batteryStatus) {
    Write-Output "Battery Status: $batteryStatus"
} else {
    Write-Output "PSU Status: $psuStatus"
}