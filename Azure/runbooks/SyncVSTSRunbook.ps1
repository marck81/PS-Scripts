<#
.SYNOPSIS 
    Syncs all runbooks in a VSTS git repository to an Azure Automation account.

.DESCRIPTION
    Syncs all runbooks in a VSTS git repository to an Azure Automation account within the RunBooks folder.
    - A secure variable is needed to hold the personal access token so that the runbook can authenticate with VSTS-
    - A webhook for this runbook is needed "Sync-VSTS". The web hook url is needed for a service hook in vsts.
       https://s2events.azure-automation.net/webhooks?token=kk9JEgcBfD1O9ArG4ZsjNvRs%2bqZgEeTHtyAHWzkb7M8%3d
    
    
    
        

.NOTES
    AUTHOR: marcosfri@youforce.net
    LASTEDIT: 30-11-2017
#>
    param (
        
        [string] $VSOCredentialName = 'VSOCredential',
        [string] $VSOAccount = 'raet',
        [string] $VSORepository = "UpdatebuildEnviroment",
        [string] $ResourceGroupName = 'we-s-rsg-vsts',
        [string] $AutomationAccountName = 'we-s-aut-automationvsts'
        
        )

    [String] $verbosePreference = "Continue"
    $psExtension = ".ps1"

    Write-Output "Connecting to Azure"
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
        Get-AzureRmSubscription –SubscriptionName "Raet Development & Test" | Select-AzureRmSubscription
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



    $VSOCred = Get-AutomationPSCredential -Name $VSOCredentialName
    if ($VSOCred -eq $null)
    {
        throw "Could not retrieve '$VSOCredentialName' credential asset. Check that you created this asset in the Automation service."
    }   
    $VSOAuthUserName = $VSOCred.UserName
    $VSOAuthPassword = $VSOCred.GetNetworkCredential().Password

    write-verbose $VSOAuthUserName
    write-verbose $VSOAuthPassword

    #Creating authorization header using 
    $basicAuth = ("{0}:{1}" -f $VSOAuthUserName,$VSOAuthPassword)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

    $user = "marcosfri@youforce.net"
    $token = "q2xs27mnim5jvi4sautkqi57dxpnhwjb5vxur7liftsxwyvvilda"
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

    #URL acces VSTS
    $VSOURL = "https://" + $VSOAccount + ".visualstudio.com/Application%20Lifecycle%20Management/_apis/git/repositories/" +
                $VSORepository + "/items?recursionlevel=full&includecontentmetadata=true&versionType=branch&api-version=1.0"  
            
    Write-Verbose("Connecting to VSO using URL: $VSOURL")
    $results = Invoke-RestMethod -Uri $VSOURL -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    #Take the folder.
    $folderObj = @()
    foreach ($item in $results.value)
    {
        if ($item.gitObjectType -eq "tree")
        {
            $folderObj += $item
        }
    }


    for ($i = $folderObj.count - 1; $i -ge 0; $i--)
    {
        Write-Verbose("Processing files in $folderObj[$i]")   
        $folderURL = "https://" + $VSOAccount + ".visualstudio.com/Application%20Lifecycle%20Management/_apis/git/repositories/" +
            $VSORepository + "/items?scopepath=" + $folderObj[$i].path + "&recursionlevel=OneLevel&includecontentmetadata=true&versionType=branch&api-version=1.0" 

        $results = Invoke-RestMethod -Uri $folderURL -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

        foreach ($item in $results.value)
        {
            Write-Verbose($item.gitObjectType)            
            Write-Verbose($item.path)
            if (($item.gitObjectType -eq "blob") -and ($item.path -match '/RunBooks') -and ($item.path -match $psExtension))
            {
                $pathsplit = $item.path.Split("/")
                $filename = $pathsplit[$pathsplit.Count - 1]
                $tempPath = Join-Path -Path $env:SystemDrive -ChildPath "temp"
                $outFile = Join-Path -Path $tempPath -ChildPath $filename

                Write-Verbose $tempPath
                Write-Verbose $outFile

                Invoke-RestMethod -Uri $item.url -Method Get -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -OutFile $outFile
                
                #Get the runbook name
                $fname = $filename
                $tempPathSplit = $fname.Split(".")
                $runbookName = $tempPathSplit[0]

                Write-Verbose "RunBook Name: $outFile " 

                #Import ps1 files into Automation, create one if doesn't exist
                Write-Verbose("Importing runbook $runbookName into Automation Account")
                $rb = Get-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Name $runbookName -ResourceGroupName $ResourceGroupName -ErrorAction "SilentlyContinue"  
                if ($rb -eq $null)
                {
                    Write-Verbose("Runbook $runbookName doesn't exist, creating it")
                    New-AzureRmAutomationRunbook -Type 'PowerShell' -AutomationAccountName $AutomationAccountName -Description 'VSTS Control RunBook' -Name $runbookName -ResourceGroupName $ResourceGroupName           
                        
                }  
                #Update the runbook, overwrite if existing.
                Import-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Force -LogVerbose $True -Name $runbookName -Path $outFile -ResourceGroupName $ResourceGroupName -Type 'PowerShell' -Publish
                   
                
                
                

            }
        }
    }






    
