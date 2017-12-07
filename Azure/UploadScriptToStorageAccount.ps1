# #############################################################################
# Add Script to Storage Account.
# AUTHOR: marcosfri@youforce.net
# #############################################################################
#region variables

$storageaccountname = "scriptsforextencionsa"
$ResourceGroupName = 'we-s-rsg-vsts'
$VMName = 'we-p-vm-vstsbld04'
$file = 'C:\MyStuff\Get-Process.ps1'

#endregion

$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
# create storage account
New-AzureRMStorageAccount -ResourceGroupName $ResourceGroupName -Location $vm.Location -StorageAccountName $storageaccountname -SkuName Standard_LRS -Kind BlobStorage -AccessTier Cool
# get storage account key
$key = (Get-AzureRmStorageAccountKey -Name $storageaccountname -ResourceGroupName $ResourceGroupName)[0].Value
# create storage context
$storagecontext = New-AzureStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $key
# create a container called scripts
New-AzureStorageContainer -Name "scriptsps" -Context $storagecontext  -Permission Blob
#upload the file
Set-AzureStorageBlobContent -Container "scriptsps" -File $file -BlobType Block -Blob "Get-Process.ps1" -Context $storagecontext -force


#to delete!!!!!
Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "GetProcesses" -Location $vm.Location -StorageAccountName $storageaccountname -StorageAccountKey $key -FileName "Get-Process.ps1" -ContainerName "scriptsps" -RunFile "Get-Process.ps1" 


#region get script extension status
$output = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "GetProcesses" -Status #-Debug
$text = $output.SubStatuses[0].Message
$result = [regex]::Replace($text, "\\n", "`n")
Write-Host $result

#endregion