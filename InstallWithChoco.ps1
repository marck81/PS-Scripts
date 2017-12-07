<#
.SYNOPSIS
	Update Vm with specific component using choco.
.DESCRIPTION
	This Azure Automation PowerShell Workflow Runbook Start/Stop Azure VM in parallel on schedule based on two VM Tags (PowerOn/PowerOff).
.NOTES
.LINK
http://www.raet.nl
#>
$chocoPath = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine")
$ChocoFile = "choco.exe"
$source = [System.IO.Path]::Combine($chocoPath, $ChocoFile)  

#Enables/Disables allowGlobalConfirmation, which will install or update without confirmation 
#choco feature enable -n=allowGlobalConfirmation
#choco feature disable -n=allowGlobalConfirmation

#& $source  --version

#[17-11-2017] INSTALLED
# & $source install dotnetcore-runtime.install 1.0.1

#[21-11-2017] .NET Core SDK 2.0.0 NOT INSTALLED
#& $source install dotnetcore-sdk --version 2.0.0
    

