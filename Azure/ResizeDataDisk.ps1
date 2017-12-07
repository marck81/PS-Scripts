# #############################################################################
# Resize Azure Data Disks using PowerShell 
# Description: Script for increasing the size of existing Azure VM data disks.
# AUTHOR: marcosfri@youforce.net.

#Notes:
# #############################################################################

#Connect to azure.
Login-AzureRmAccount

$rgName = 'BuldResGrp'
$vmName = "ServerTest01"



