# #############################################################################
# Clone VM
# AUTHOR: marcosfri@youforce.net
# #############################################################################

#Region connect to Azure
Login-AzureRmAccount
Get-Command -CommandType Alias -Module AzureRM*
Get-AzureRmContext
Set-AzureRmCurrentStorageAccount -ResourceGroupName 'BuldResGrp' -Name 'buldresgrpdisks998'

#endregion

#region Capture a Generalized VHD
#Previously generalize the vm using sysprep ()remove all personal information.
# 1.Deallocate the VM resources.
Stop-AzureRmVM -ResourceGroupName 'BuldResGrp' -Name 'BuildServ01' -Force

#2.Set the status of the virtual machine to Generalized. 
Set-AzureRmVm -ResourceGroupName 'BuldResGrp' -Name 'BuildServ01' -Generalized

#3.Check the status pf the vM (The OSState/generalized section for the VM should have the DisplayStatus set to VM generalized)
$vm = Get-AzureRmVM -ResourceGroupName 'BuldResGrp' -Name 'BuildServ01' -Status
$vm.Statuses

#4.Create the image
#Create an unmanaged virtual machine image in the destination storage container. The image is created in the same storage 
#account as the original virtual machine.
Save-AzureRmVMImage -ResourceGroupName 'BuldResGrp' -Name 'BuildServ01'  `
   -DestinationContainerName 'images' -VHDNamePrefix 'winimage'  `
   -Path 'C:\vm-BuildServ01.json'

ise 'C:\vm-BuildServ01.json'

#endregion




#region Create a new VM based on a captured image

# Enter a new user name and password to use as the local administrator account 
    # for remotely accessing the VM.
$cred = Get-Credential

# Name of the storage account where the VHD is located. This example sets the 
   # storage account name as "myStorageAccount"
$storageAccName = "buldresgrpdisks998"

#resource group
$rgName = 'BuldResGrp'

#vnetName
$vnetName = 'BuldResGrp-vnet'

#location
$location = 'West Europe'

# Name of the virtual machine. This example sets the VM name as "myVM".
$vmName = "BuildServ02"

# Size of the virtual machine
$vmSize = "Standard_A1"

# Computer name for the VM. This examples sets the computer name as "myComputer".
$computerName = "BuildServ02"

# Name of the disk that holds the OS. This example sets the 
 # OS disk name as "myOsDisk"
$osDiskName = "buildServ02Disk"

# Assign a SKU name.
$skuName = "Standard_LRS"

# Get the storage account where the uploaded image is stored.
$storageAcc = Get-AzureRmStorageAccount -ResourceGroupName $rgName -AccountName $storageAccName

# Set the VM name and size
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize

 #**************************************************************************

 
    #region Create a public IP address and network interface

    #1.Create a public IP address.
    $ipName = "BuildServ02ip"
    $pip = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $rgName -Location $location `
        -AllocationMethod Dynamic

    #2.Create the NIC.
    #get the vnet.
    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName  $rgName -Name $vnetName
    $nicName = "buildserv02nic"
    $nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location `
        -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id

    #endregion


#Set the Windows operating system configuration and add the NIC
$vm = Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $computerName `
        -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id





$imageURI = 'https://buldresgrpdisks998.blob.core.windows.net/system/Microsoft.Compute/Images/images/winimage-osDisk.6c155119-24cb-4735-a218-2daba034ecc2.vhd'


# Create the OS disk URI
$osDiskUri = '{0}vhds/{1}-{2}.vhd' -f $storageAcc.PrimaryEndpoints.Blob.ToString(), $vmName.ToLower(), $osDiskName

# Configure the OS disk to be created from the existing VHD image (-CreateOption fromImage).
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri `
    -CreateOption fromImage -SourceImageUri $imageURI -Windows

# Create the new VM
New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vm

#endregion

         