<#
.SYNOPSIS
	Start/Stop VSTS Azure VMs in parallel on schedule based on two VM Tags (PowerOn/PowerOff). Please use UTC time in the tags. 
.DESCRIPTION
	Use the Custom Script Extension to check if a process is running on each VM before
.NOTES v1.0.1
.LINK
#>

    #region const   
    #$ErrorActionPreference = 'Stop'
    [String] $verbosePreference = "Continue"
    $currentTime = (Get-Date).ToUniversalTime()

    #endregion

    #region variables BuildPerm  

    $ResourceGroupName = 'we-s-rsg-vsts' 
    $StorageAcccountName = 'scriptsforextencionsa'
    $ScriptExtensionName = 'CustomScriptExtension'
    $ContainerName = 'scriptsps'
    $FileName = 'Get-Process.ps1'   


    #endregion

    #region Connection to Azure

    Write-Output "Connecting to Azure"
    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception.Message
            throw $_.Exception
        }
    }

    #endregion   
             
        #Get VMs of the resource group.
        $AzVms = Get-AzureRmVm -ResourceGroupName $ResourceGroupName 

        Foreach ($AzVm in $AzVms)
        {
            try
            {
                $vmInstance = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $AzVm.Name -Status
                if($vmInstance.Statuses | where Code -match "PowerState/running")  
                {
                    Write-Output $AzVm.Name
                    Write-Output ": VM running"
                
                    #Get the Vm Time.
                    $azTime = [datetime]::Now
                    $TimeShort = $azTime.ToString('HH:mm')
                    $TimeVm = $azTime
                    
                    #AutoShutdownSchedule disable execution runbook.
                    if($AzVm.Tags.EnableVSTSAutoshutdown -match "false")
                    {
                        $Execution ='Disabled AutoShutdown funcionality on the server'
                    }
                    elseif($AzVm.Tags.AutoShutdownSchedule -match $azTime.DayOfWeek) 
                    {
                        $Execution ='NotRequiredWeekendMatch'
                    }
                    else
                    {                  
                    
                        #Daily execution VM
                        if ([datetime]$AzVm.Tags.VSTSPowerOn -lt [datetime]$AzVm.Tags.VSTSPowerOff)
                        {
                            if ($TimeVm -gt [datetime]$AzVm.Tags.VSTSPowerOff -or $TimeVm -lt [datetime]$AzVm.Tags.VSTSPowerOn) 
                            {
                                #Check if a build is running in the VM.
                                Write-output "Stopping the VM...."
                                #get the access key for an Azure storage account.
                                $key =(Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $StorageAcccountName).Key1   
                                $arguments = "-processName Agent.Worker"                                  
                                Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
                                                    -VMName $AzVm.Name  `
                                                    -Name $ScriptExtensionName `
                                                    -Location $AzVm.Location  `
                                                    -StorageAccountName $StorageAcccountName  `
                                                    -StorageAccountKey $key `
                                                    -FileName $FileName  `
                                                    -ContainerName $ContainerName  `
                                                    -RunFile $FileName  `
                                                    -Argument $arguments

                                #Get script extension status
                                $output = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VMName $AzVm.Name -Name $ScriptExtensionName -Status #-Debug
                                $text = $output.SubStatuses[0].Message
                                $result = [regex]::Replace($text, "\\n", "`n")
                                Write-output $result
                                #Stop the vm if build not running.
                                if ($result -eq "false") 
                                {
                                    Write-Output "Shutting down the VM"
                                    $Result = Stop-AzureRmVm -Name $AzVm.Name -ResourceGroupName $ResourceGroupName -Force
                                    $Status = ($Result.StatusCode)					
                                    $Execution = 'Stopped'
                                }
                                else
                                {
                                    $Execution = 'BuildRunningOnServer'
                                }
                            }
                            else 
                            {
                                $Execution = 'NotRequired'
                            }
                        }
                        else
                        {
                            #Night execution VM
                            #For now this case is not considered.
                        }                       
                    }

                }
                else
                {
                    Write-Output $AzVm.Name
                    Write-Output ": VM stopped"                    
                
                    #Get the Vm Time.
                    $azTime = [datetime]::Now
                    $TimeShort = $azTime.ToString('HH:mm')
                    $TimeVm = $azTime

                    #AutoShutdownSchedule disable execution runbook.
                    if($AzVm.Tags.EnableVSTSAutoshutdown -match "false")
                    {
                        $Execution ='Disabled AutoShutdown funcionality on the server'
                    }
                    elseif($AzVm.Tags.AutoShutdownSchedule -match $azTime.DayOfWeek) 
                    {
                        $Execution ='NotRequiredWeekendMatch'
                    }
                    else
                    {
                        if ([datetime]$AzVm.Tags.VSTSPowerOn -lt [datetime]$AzVm.Tags.VSTSPowerOff)
                        {
                            if ($TimeVm -gt [datetime]$AzVm.Tags.VSTSPowerOn -and $TimeVm -lt [datetime]$AzVm.Tags.VSTSPowerOff)
                            {
                                Write-Output "Starting the VM"
                                $Result = Start-AzureRmVm -Name $AzVm.Name -ResourceGroupName $ResourceGroupName 
                                $Status = ($Result.StatusCode)					
                                $Execution = 'Started'
                            }
                            else
                            {
                                $Execution = 'NotRequired'
                            } 
                        }

                    }


                }
                
                $Prop = [ordered]@{
                    AzureVM       = $AzVm.Name
                    ResourceGroup = $ResourceGroupName
                    #PowerState    = (Get-Culture).TextInfo.ToTitleCase($AzVm.PowerState)
                    PowerState    = (Get-Culture).TextInfo.ToTitleCase($vmInstance.Statuses)
                    PowerOn       = $AzVm.Tags.VSTSPowerOn
                    PowerOff      = $AzVm.Tags.VSTSPowerOff
                    StateChange   = $Execution
                    StatusCode    = $Status
                    TimeStamp     = $TimeVm
                }


            }
            Catch
            {
                #Comentar para devolver el error como estado de objeto.
                $Prop = [ordered]@{
                    AzureVM       = $AzVm.Name
                    ResourceGroup = $ResourceGroupName
                    #PowerState    = (Get-Culture).TextInfo.ToTitleCase($AzVm.PowerState)
                    PowerState    = (Get-Culture).TextInfo.ToTitleCase($vmInstance.Statuses)
                    PowerOn       = $AzVm.Tags.VSTSPowerOn
                    PowerOff      = $AzVm.Tags.VSTSPowerOff
                    StateChange   = 'Unknown'
                    StatusCode    = 'Error'
                    TimeStamp     = $TimeVm
                }
            }
            Finally
            {
                $Obj = New-Object PSObject -Property $Prop
		        Write-Output -InputObject $Obj
            }	
            
        }   
   

    
    Write-Output "Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"

