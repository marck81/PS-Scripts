<#
.SYNOPSIS
	Start/Stop Azure VMs in parallel on schedule based on two VM Tags (PowerOn/PowerOff). Please use UTC time in the tags. 
.DESCRIPTION
	This Azure Automation PowerShell Workflow Runbook Start/Stop Azure VM in parallel on schedule based on two VM Tags (PowerOn/PowerOff).
.NOTES
.LINK
http://www.raet.nl
#>

Workflow StartStopAzureVMsParallel {

Param (

	[Parameter(Mandatory=$false,Position=1)]
	[string]$AzureSubscription = 'Raet Development & Test'
		
)

$ErrorActionPreference = 'Stop'
$currentTime = (Get-Date).ToUniversalTime()
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

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
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Set-AzureRmContext -SubscriptionName $AzureSubscription

$AzureResourceGroups = Get-AzureRmResourceGroup

Foreach ($AzureResourceGroup in $AzureResourceGroups) 
{  
$AzVms = Get-AzureRmVm -ResourceGroupName $AzureResourceGroup.ResourceGroupName -Status

Foreach -Parallel($AzVm in $AzVms) {

Try 
	{
		### Running VM ###

		If ($AzVm.PowerState  -icontains 'VM running') {
			
            $azTime = [datetime]::Now
			$TimeShort = $azTime.ToString('HH:mm')
			$TimeVm = $azTime
		
            if($AzVm.Tags.AutoShutdownSchedule -match $azTime.DayOfWeek){

            $Execution ='NotRequiredWeekendMatch'

             } 
           Else {

			### 00:00---On+++Off---00:00 ###
			If ([datetime]$AzVm.Tags.PowerOn -lt [datetime]$AzVm.Tags.PowerOff) {
				If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOff -or $TimeVm -lt [datetime]$AzVm.Tags.PowerOn) {
					
                    	$Result = Stop-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup.ResourceGroupName -Force
						$Status = ($Result.StatusCode)
					
					$Execution = 'Stopped'
				} Else {$Execution = 'NotRequired'}
			
			### 00:00+++Off---On+++00:00 ###
			} Else {
				If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOff -and $TimeVm -lt [datetime]$AzVm.Tags.PowerOn) {
					 
						$Result = Stop-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup.ResourceGroupName -Force
						$Status = ($Result.StatusCode)
					
					$Execution = 'Stopped'
				} Else {$Execution = 'NotRequired'}
			}
        }
			
		### Not running VM (stopped/deallocated/suspended etc) ###
		} Else {
			
            $azTime = [datetime]::Now
			$TimeShort = $azTime.ToString('HH:mm')
			$TimeVm = $azTime


			if($AzVm.Tags.AutoShutdownSchedule -match $azTime.DayOfWeek){

            $Execution ='NotRequiredWeekendMatch'

             } 

			### 00:00---On+++Off---00:00 ###
            
            Else{




			If ([datetime]$AzVm.Tags.PowerOn -lt [datetime]$AzVm.Tags.PowerOff) {
				
                If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOn -and $TimeVm -lt [datetime]$AzVm.Tags.PowerOff) {
					 
						$Result = Start-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup.ResourceGroupName
					    $Status = ($Result.StatusCode)
					    $Execution = 'Started'

				} Else {$Execution = 'NotRequired'}
			
			### 00:00+++Off---On+++00:00 ###
			} Else {
				If ($TimeVm -gt [datetime]$AzVm.Tags.PowerOn -or $TimeVm -lt [datetime]$AzVm.Tags.PowerOff) {
					
						$Result = Start-AzureRmVm -Name $AzVm.Name -ResourceGroupName $AzureResourceGroup.ResourceGroupName
						$Status = ($Result.StatusCode)
					
					$Execution = 'Stopped'
				} Else {$Execution = 'NotRequired'}
			}
		}
}
		$Prop = [ordered]@{
			AzureVM       = $AzVm.Name
			ResourceGroup = $AzureResourceGroup.ResourceGroupName
			PowerState    = (Get-Culture).TextInfo.ToTitleCase($AzVm.PowerState)
			PowerOn       = $AzVm.Tags.PowerOn
			PowerOff      = $AzVm.Tags.PowerOff
			StateChange   = $Execution
			StatusCode    = $Status
			TimeStamp     = $TimeVm
		}
	}
Catch
	{
		$Prop = [ordered]@{
			AzureVM       = $AzVm.Name
			ResourceGroup = $AzureResourceGroup.ResourceGroupName
			PowerState    = (Get-Culture).TextInfo.ToTitleCase($AzVm.PowerState)
			PowerOn       = $AzVm.Tags.PowerOn
			PowerOff      = $AzVm.Tags.PowerOff
			StateChange   = 'Unknown'
			StatusCode    = 'TagNotPresent'
			TimeStamp     = $TimeVm
		}
	}
Finally
	{
		$Obj = New-Object PSObject -Property $Prop
		Write-Output -InputObject $Obj
	}	
} #End Foreach

} #end Forceach resourcegroups 
  Write-Output "Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"
} #End Workflow 

