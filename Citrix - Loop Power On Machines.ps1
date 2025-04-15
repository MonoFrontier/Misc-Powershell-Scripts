#List Machine Catalog and PowerState
$list = @($names)

#Loop Until Machines are Powered On
    foreach ($machine in $list)
    {
           Do {
                #If Machine Power State 'On' is not true, create Power Action to Turn On
                if(!(((Get-BrokerMachine -HostedMachineName $machine).PowerState -eq 'On')))
                {
                    New-BrokerHostingPowerAction -MachineName $machine -Action TurnOn
                    #Pause for 1 minutes to allow Machine Power State to update
                    Start-Sleep -Seconds 60
                }   Else {Write-Host 'Machine is Already Powered On!'}
            } Until((Get-BrokerMachine -HostedMachineName $machine).PowerState -eq 'On')

    }
    
foreach($machine in $list){
Get-BrokerMachine -HostedMachineName $machine -Property HostedMachineName,PowerState | Out-File -FilePath 'C:\Temp\MachinePowerStateResults.txt' -Append}