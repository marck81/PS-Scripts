# #############################################################################
# Attach a data disk to a Windows VM using PowerShell 
# Description: Attach both new and existing disks to a Windows virtual .
# AUTHOR: marcosfri@youforce.net.

#Notes: The size of the controls how many data disks you can attach.
# #############################################################################

#region connect to Azure

Login-AzureRmAccount
##Select Raet Subscription.
#Get-AzureRmSubscription –SubscriptionName "Visual Studio Enterprise" | Select-AzureRmSubscription # Get all the subscriptions
Get-Command -CommandType Alias -Module AzureRM*
Get-AzureRmContext
Set-AzureRmCurrentStorageAccount -ResourceGroupName 'BuldResGrp' -Name 'buldresgrpdisks998'


#endregion

$rgName = 'BuldResGrp'
$vmName = "ServerTest01"
$storageType = 'StandardLRS'
$location = 'West Europe'
$dataDiskName = ($vmName + '_datadisk1')

#region [MANAGED] Add an empty data disk to virtual machine StandardLRS.

$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB 5
$dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName

$vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName
$vm = Add-AzureRmVMDataDisk $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
Update-AzureRmVM -VM $vm -ResourceGroupName $rgName

#Initialize the managed disk. Prepare data disks
#https://blogs.msdn.microsoft.com/azureedu/2017/02/11/new-managed-disk-storage-option-for-your-azure-vms/
#https://github.com/imjoseangel/powershell/blob/master/Initialize_Disk.ps1

Get-Disk | Where partitionstyle -eq 'raw' | `
Initialize-Disk -PartitionStyle MBR -PassThru | `
New-Partition -AssignDriveLetter -UseMaximumSize | `
Format-Volume -FileSystem NTFS -NewFileSystemLabel "DataDisk01" -Confirm:$false

#endregion



#region [UNMANAGED] Add an empty data disk to stored account.





#endregion