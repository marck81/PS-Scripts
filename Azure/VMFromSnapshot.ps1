# #############################################################################
# Use PowerShell to take a snapshot
# AUTHOR: marcosfri@youforce.net
# Description:The following steps show you how to get the VHD disk to be copied, create the snapshot configurations, 
#  and take a snapshot of the disk by using the New-AzureRmSnapshot cmdlet.
#NOTES: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/managed-disks-overview#managed-disk-snapshots

# #############################################################################

#region connect to Azure

Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName "Raet Development & Test" | Select-AzureRmSubscription
Get-Command -CommandType Alias -Module AzureRM*
Get-AzureRmContext
#Set-AzureRmCurrentStorageAccount -ResourceGroupName 'BuldResGrp' -Name 'buldresgrpdisks998'

#endregion

#region Create Snapshot from Disk.

$resourceGroupName = 'we-s-rsg-vsts' 
$location = 'West Europe'
$dataDiskName = 'we-p-vm-vstsbld04_OsDisk' 
$snapshotName = 'Snapshot_vm-vstsbld04_01'  

#Get the VHD disk to be copied
$disk = Get-AzureRmDisk -ResourceGroupName $resourceGroupName -DiskName $dataDiskName 

#Create the snapshot configurations.If you plan to use the snapshot to create a Managed Disk and attach it a VM that needs to be high performing, use the parameter -AccountType PremiumLRS
$snapshot =  New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $location #-AccountType PremiumLRS


#Take the snapshot.
New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName 

#endregion

#region create a new VM


    #Provide the subscription Id
    $subscriptionId = '1bfce26d-ce7a-4197-a184-68e1289631b7'

    #Provide the name of your resource group
    $resourceGroupName = 'we-s-rsg-vsts' 

    #Provide the name of the snapshot that will be used to create OS disk
    $snapshotName = 'BeforeCobol221117'

    #Provide the name of the OS disk that will be created using the snapshot
    $osDiskName = 'we-p-vm-vstsbldDev01_OsDisk'

    $storageType = 'PremiumLRS'

    #Provide the name of an existing virtual network where virtual machine will be created
    $virtualNetworkName = 'we-s-vnet-devtest01'

    #Provide the name of the virtual machine
    $virtualMachineName = 'we-p-vm-vstsblDev01'

    #Subnet id
    $virtualsubnetid = '/subscriptions/1bfce26d-ce7a-4197-a184-68e1289631b7/resourceGroups/we-s-rsg-network/providers/Microsoft.Network/virtualNetworks/we-s-vnet-devtest01/subnets/we-s-subnet-VSTS'

    #Provide the size of the virtual machine
    #e.g. Standard_DS3
    #Get all the vm sizes in a region using below script:
    #e.g. Get-AzureRmVMSize -Location westus  we-s-rsg-network
    #$virtualMachineSize = 'Standard_F8s'
    $virtualMachineSize = 'Standard_DS1_v2'

    #Set the context to the subscription Id where Managed Disk will be created
    Select-AzureRmSubscription -SubscriptionId $SubscriptionId

    $snapshot = Get-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName 
 
    $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy
 
    $disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $osDiskName

    #Initialize virtual machine configuration
    $VirtualMachine = New-AzureRmVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize

    #Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
    
    $VirtualMachine = Set-AzureRmVMBootDiagnostics -VM $VirtualMachine -disable 

    #Create a public IP for the VM  
    #$publicIp = New-AzureRmPublicIpAddress -Name ($VirtualMachineName.ToLower()+'_ip') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -AllocationMethod Dynamic

    #Get the virtual network where virtual machine will be hosted
    $vnet = Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName 'we-s-rsg-network'

    # Create NIC in the first subnet of the virtual network 
    #$nic = New-AzureRmNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic1') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id
    $nic = New-AzureRmNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic1') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $virtualsubnetid #-PublicIpAddressId $publicIp.Id

    $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

    #Create the virtual machine with Managed Disk
    New-AzureRmVM -VM $VirtualMachine -ResourceGroupName $resourceGroupName -Location $snapshot.Location



#endregion

#region Clean up deployment

#Remove-AzureRmResourceGroup -Name myResourceGroup

#endregion