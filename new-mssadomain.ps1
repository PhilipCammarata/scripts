# https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-

function New-MSSADomain {
    # Need to install Active Directory Domain Services before we have access to the AD PowerShell modules
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    # Just in case it is not already imported
    Import-Module ADDSDeployment

    # Many of these values are default but the big ones are -DomainName and -DomainNetBiosName
    Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "WinThreshold" -DomainName "mssa.cammarata.me" -DomainNetbiosName "MSSA" -ForestMode "WinThreshold" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true
}

New-MSSADomain

Restart-Computer -Force
