<#
.SYNOPSIS
	Get .Net Core Info
.DESCRIPTION
	Get all the Information about .Net Core Installed
.NOTES
.LINK
#>
Function Get-CoreInfo {
    if(Test-Path "$env:programfiles/dotnet/"){
        try{

            [Collections.Generic.List[string]] $info = dotnet

            $versionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like "*version*:*"} )

            $runtimes = (ls "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name | Out-String

            $sdkVersion = dotnet --version

            $fhVersion = (($info[$versionLineIndex]).Split(':')[1]).Trim()

            return "SDK version: `r`n$sdkVersion`r`n`r`nInstalled runtime versions:`r`n$runtimes`r`nFramework Host:`r`n$fhVersion"
        }
        catch{
            $errorMessage = $_.Exception.Message

            Write-Host "Something went wrong`r`nError: $errorMessage"
        }
    }
    else{
    
        Write-Host 'No SDK installed'
        return ""
    }
}