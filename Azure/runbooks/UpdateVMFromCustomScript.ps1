<#
.SYNOPSIS
	Execute PS File on a VM using Custom Script Extension
.DESCRIPTION
    Use to update the VMs in the resource group.
    Use the Tag 'UpdateCMEnabled : true/false'
	Use the Custom Script Extension and execute an PS file stored on $StorageAcccountName. This
      file contains the command to update the VM
      
.NOTES
.LINK
#>
#$VerbosePreference = 'Continue' #remove when publishing runbook

#region variables
   
    $ResourceGroupName = 'we-s-rsg-vsts'
    $StorageAcccountName = 'scriptsforextencionsa'
    $ContainerName = 'scriptsps'
    $FileName = 'InstallWithChoco.ps1'          
    $ScriptExtensionName = 'CustomScriptExtension'

#endregion

#region Connection to Azure

    write-Output "Connecting to Azure"
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

#region execute command using Update Custom Script Extension.

    #Get VMs of the resource group.
    $AzVms = Get-AzureRmVm -ResourceGroupName $ResourceGroupName 
    Foreach ($AzVm in $AzVms)
    {
        try
        {
       
            Write-Output '****Executing Custom Script Extension '
            #Get the Vm Time.
            $azTime = [datetime]::Now
            $TimeShort = $azTime.ToString('HH:mm')
            $TimeVm = $azTime 
        
            $vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $AzVm.Name -Status
            if (($vm.Statuses | where Code -match "PowerState/running") -and ($AzVm.Tags.UpdateCMEnabled -match "true"))
            {

                #get the access key for an Azure storage account.
                $key =(Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $StorageAcccountName).Key1     
                
                #Set the custom script extension to the VM     
                Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
                                                        -VMName $AzVm.Name  `
                                                        -Name $ScriptExtensionName `
                                                        -Location $AzVm.Location  `
                                                        -StorageAccountName $StorageAcccountName  `
                                                        -StorageAccountKey $key `
                                                        -FileName $FileName  `
                                                        -ContainerName $ContainerName  `
                                                        -RunFile $FileName 
                                                        #-Argument $arguments     
                $Execution = 'VM Updated'

            }
            else
            {
                $Execution = 'VM NOT Updated'
            }

            #region get script extension status

            $output = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VMName $AzVm.Name -Name $ScriptExtensionName -Status #-Debug
            $text = $output.SubStatuses[0].Message
            $result = [regex]::Replace($text, "\\n", "`n")

            Write-Output $result

            #endregion



            $Prop = [ordered]@{
                    AzureVM       = $AzVm.Name
                    ResourceGroup = $ResourceGroupName                   
                    PowerState    = (Get-Culture).TextInfo.ToTitleCase($vm.Statuses)
                    UpdateState   = $AzVm.Tags.UpdateCMEnabled                   
                    StateChange   = $Execution
                    StatusResult  = $result
                    TimeStamp     = $TimeVm
                }
            
    
                                                
        }
        Catch
        {
            $Prop = [ordered]@{
                AzureVM       = $AzVm.Name
                ResourceGroup = $ResourceGroupName                   
                PowerState    = (Get-Culture).TextInfo.ToTitleCase($vm.Statuses.DisplayStatus)
                UpdateState   = $AzVm.Tags.UpdateCMEnabled                   
                StateChange   = 'Unknown'
                StatusResult  = $_.Exception.Message
                TimeStamp     = $TimeVm
            }
           
        }
        Finally
        {
            $Obj = New-Object PSObject -Property $Prop
		    Write-Output -InputObject $Obj
        }	

    }
    $currentTime = (Get-Date).ToUniversalTime()
    Write-Output "Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"

   


#endregion

