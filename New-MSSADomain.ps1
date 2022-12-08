function New-MSSADomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$NetBiosName
    )

    # Need to install Active Directory Domain Services before we have access to the AD PowerShell modules
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    # Just in case it is not already imported
    Import-Module ADDSDeployment

    # Many of these values are default but the big ones are -DomainName and -DomainNetBiosName
    Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "WinThreshold" -DomainName $DomainName -DomainNetBiosName $NetBiosName -ForestMode "WinThreshold" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true
}

New-MSSADomain -DomainName "mssa.cammarata.me" -NetBiosName "MSSA"

#Invoke-Command -FilePath .\New-MSSADomain.ps1 -ComputerName WS2022-DC
