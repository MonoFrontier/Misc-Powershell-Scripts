# Specify the name of the power plan to assign
$planName = "High performance"
$highPerformanceGUID = "8C5E7FDA-E8BF-4A96-9A85-A6E23A8C635C"

# Find the GUID of the specified power plan
$powerPlan = powercfg /list | Select-String -Pattern $planName | ForEach-Object {
    $_ -match 'GUID: (.+?) ' | Out-Null
    $matches[1]
}

# Set the power plan if it exists otherwise create using Microsoft default value
if ($powerPlan) {
    powercfg /setactive $powerPlan
} else {
    powercfg /duplicatescheme $highPerformanceGUID
    powercfg /setactive $highPerformanceGUID
}

powercfg /getactivescheme