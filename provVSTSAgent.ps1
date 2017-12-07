# #############################################################################
# Provision VSTS agent
# AUTHOR: marcosfri@youforce.net
# Description: Download the vsts agent, install on server, register and add
#                 to specific pool.
#NOTES: Modify Test-AgentExists for check if a WS exists with this name

# #############################################################################
[CmdletBinding()]
param(
    #[Parameter(Mandatory)]
    [string] $vstsAccount = 'raet',
    #[Parameter(Mandatory)]
    [string] $vstsUser = 'marcosfri@youforce.net',
    #[Parameter(Mandatory)]
    [string] $vstsUserPassword = 'q2xs27mnim5jvi4sautkqi57dxpnhwjb5vxur7liftsxwyvvilda',    
    [string] $agentWorkDirectory = 'E:\Agents\1\_work',
    #[Parameter(Mandatory)]
    [string] $agentInstallPath = 'c:\Agents',
    #[Parameter(Mandatory)]
    [string] $agentName = 'vstsbld01-Agent01',
    #[Parameter(Mandatory)]
    [string] $poolName = 'PermTestPool',
    [string] $windowsLogonAccount , 
    [string] $windowsLogonPassword 

)

#region Configuration script

$ErrorActionPreference = "Stop" #Stop if something going wrong.
pushd $PSScriptRoot # working dirirectory
Set-PSDebug -Strict #returns an exception if a variable is referenced before the value is asigned.

#endregion


#region Functions

function Handle-Error
{
    [CmdletBinding()]
    param(
    )

    $errormessage = $error[0].Exception.Message
    if ($errormessage)
    {
        Write-Host -Object "ERROR: $errormessage" -ForegroundColor Red
    }

    exit -1
}

function Test-ValidPath
{
    param(
        [string] $Path
    )
    
    $isValid = Test-Path -Path $Path -IsValid -PathType Container
    
    try
    {
        [IO.Path]::GetFullPath($Path) | Out-Null
    }
    catch
    {
        $isValid = $false
    }
    
    return $isValid
}

function Test-Parameters
{
     [CmdletBinding()]
    param(
        [string] $VstsAccount,
        [string] $agentWorkDirectory
    )

    if ($VstsAccount -match "https*://" -or $VstsAccount -match "visualstudio.com")
    {
        Write-Error "VSTS account '$VstsAccount' should be ONLY the account name."
    }
    if (![string]::IsNullOrWhiteSpace($agentWorkDirectory) -and !(Test-ValidPath -Path $agentWorkDirectory))
    {
        Write-Error "Work directory '$agentWorkDirectory' is not a valid path."
    }

}

function New-AgentInstallPath
{
    [CmdletBinding()]
    param(
        [string] $agentInstallPath,
        [string] $AgentName
    )

    #[string] $agentInstallPath = $null
    #Set the folder
    #$agentInstallDir = $DriveLetter + ":"
    try
    {
        # Create the directory for this agent.
        $agentInstallPath = Join-Path -Path $agentInstallPath -ChildPath $AgentName
        New-Item -ItemType Directory -Force -Path $agentInstallPath | Out-Null
    }
    catch
    {
        $agentInstallPath = $null
        Write-Error "Error creating the agent directory at $installPathDir."
    }
    return $agentInstallPath

}


function Test-AgentExists
{
    [CmdletBinding()]
    param(
        [string] $InstallPath,
        [string] $AgentName
    )
    $agentConfigFile = Join-Path $InstallPath '.agent'

    if (Test-Path $agentConfigFile)
    {
        Write-Error "Agent $AgentName is already configured in this machine"
    }

    #check vsts Ws same name exists

}

function Download-AgentPackage
{
    [CmdletBinding()]
    param(
        [string] $VstsAccount,
        [string] $vstsUser,
        [string] $VstsUserPassword
    )
    
    # Create a temporary directory where to download from VSTS the agent package (agent.zip).
    $agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $agentTempFolderName | Out-Null

    $agentPackagePath = "$agentTempFolderName\agent.zip"
    $serverUrl = "https://$VstsAccount.visualstudio.com"
    $vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent/win7-x64?`$top=1&api-version=3.0"
   

    $maxRetries = 3
    $retries = 0
    do
    {
        try
        {
            

            $basicAuth = ("{0}:{1}" -f $vstsUser, $vstsUserPassword) 
            $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
            $basicAuth = [System.Convert]::ToBase64String($basicAuth)
            $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }

            $agentList = Invoke-RestMethod -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json
            $agent = $agentList.value
            if ($agent -is [Array])
            {
                $agent = $agentList.value[0]
            }
            Invoke-WebRequest -Uri $agent.downloadUrl -Headers $headers -Method Get -OutFile "$agentPackagePath" | Out-Null
            break
        }
        catch
        {
            $exceptionText = ($_ | Out-String).Trim()
                
            if (++$retries -gt $maxRetries)
            {
                Write-Error "Failed to download agent due to $exceptionText"
            }
            
            Start-Sleep -Seconds 1 
        }
    }
    while ($retries -le $maxRetries)

    return $agentPackagePath
}

function Extract-AgentPackage
{
    [CmdletBinding()]
    param(
        [string] $PackagePath,
        [string] $Destination
    )
    
    $destShellFolder = (New-Object -ComObject shell.application).namespace("$Destination")
    $destShellFolder.CopyHere((New-Object -ComObject shell.application).namespace($PackagePath).Items(), 16)
}


function Check-AgentInstaller
{
    param(
        [string] $InstallPath
    )

    $agentExePath = [System.IO.Path]::Combine($InstallPath, 'config.cmd')

    if (![System.IO.File]::Exists($agentExePath))
    {
        Write-Error "Agent installer file not found: $agentExePath"
    }
    
    return $agentExePath
}


function Install-Agent
{
    param(
        $Config
    )

    try
    {
        # Set the current directory to the agent dedicated one previously created.
        pushd -Path $Config.AgentInstallPath

        # The actual install of the agent. Using --runasservice, and some other values that could be turned into paramenters if needed.
        $agentConfigArgs = "--unattended", "--url", $Config.ServerUrl, "--auth", "PAT", "--token", $Config.VstsUserPassword, "--pool", $Config.PoolName, "--agent", $Config.AgentName, "--runasservice"
        if (-not [string]::IsNullOrWhiteSpace($Config.WindowsLogonAccount))
        {
            $agentConfigArgs += "--windowslogonaccount", $Config.WindowsLogonAccount
        }
        if (-not [string]::IsNullOrWhiteSpace($Config.WindowsLogonPassword))
        {
            $agentConfigArgs += "--windowslogonpassword", $Config.WindowsLogonPassword
        }
        if (-not [string]::IsNullOrWhiteSpace($Config.agentWorkDirectory))
        {
            $agentConfigArgs += "--work", $Config.agentWorkDirectory
        }
        & $Config.AgentExePath $agentConfigArgs
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Agent configuration failed with exit code: $LASTEXITCODE"
        }
    }
    finally
    {
        popd
    }
}


#endregion

trap
{
   Handle-Error
}


########################### MAIN BLOCK ###############################
try
{
    Write-Host 'Validating parameters'
    #Test VSTS format and working dir..
    Test-Parameters -VstsAccount $vstsAccount -agentWorkDirectory $agentWorkDirectory

    Write-Host 'Setting agent installation location'
    #Create the folder for the agent
    $agentInstallPath = New-AgentInstallPath -agentInstallPath $agentInstallPath -AgentName $agentName

    Write-Host 'Checking for previously configured agent'
    Test-AgentExists -InstallPath $agentInstallPath -AgentName $agentName

    Write-Host 'Downloading agent package'
    $agentPackagePath = Download-AgentPackage -VstsAccount $vstsAccount -vstsUser $vstsUser -VstsUserPassword $vstsUserPassword
    #$agentPackagePath = 'C:\TESTAgent\vsts-agent-win7-x64-2.123.0.zip'

    Write-Host 'Extracting agent package contents'
    Extract-AgentPackage -PackagePath $agentPackagePath -Destination $agentInstallPath

    Write-Host 'Getting agent installer path'
    $agentExePath = Check-AgentInstaller -InstallPath $agentInstallPath

    Write-Host 'Installing agent'
    $config = @{
        AgentExePath = $agentExePath
        AgentInstallPath = $agentInstallPath
        AgentName = $agentName
        PoolName = $poolName
        ServerUrl = "https://$VstsAccount.visualstudio.com"
        VstsUserPassword = $vstsUserPassword
        WindowsLogonAccount = $windowsLogonAccount
        WindowsLogonPassword = $windowsLogonPassword
        agentWorkDirectory = $agentWorkDirectory
    }
    Install-Agent -Config $config
    
    Write-Host 'Done'



}
finally
{
    popd
}

