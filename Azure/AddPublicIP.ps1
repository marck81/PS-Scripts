#region connect to Azure

Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName "Raet Development & Test" | Select-AzureRmSubscription
Get-Command -CommandType Alias -Module AzureRM*
Get-AzureRmContext
#Set-AzureRmCurrentStorageAccount -ResourceGroupName 'BuldResGrp' -Name 'buldresgrpdisks998'

#endregion







 #1.Create a public IP address.
 #resource group
$rgName = 'we-s-rsg-vsts'
#location
$location = 'West Europe'
#nicName
$nicname = 'we-p-vm-vstsbld04-nic1'

$ipName = "vstsbld04_ip"
$pip = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $rgName -Location $location `
        -AllocationMethod Dynamic

$nic = Get-AzurermNetworkInterface -ResourceGroupName $rgName -Name $nicname
$pip = Get-AzurermPublicIPAddress -ResourceGroupName $rgName -Name $nicname
$nic.IPConfigurations[0].PublicIPAddress=$pip
# Finally set the IP address against the NIC
Set-AzureRmNetworkInterface -NetworkInterface $nic