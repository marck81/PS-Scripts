<#
.SYNOPSIS
	Install Chocolatery
.DESCRIPTION
	how to run Chocolatey commands on a remote Azure VM using Custom Script Extension
.NOTES
.LINK
#>

iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) 
