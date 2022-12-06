function Invoke-MSSAPostInstall {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [string]$LocalAdministrator,

        [string]$TimeZone = "Eastern Standard Time",

        [string]$OSDriveLabel = "OS",

        [Parameter(Mandatory)]
        [string]$InterfaceAlias,

        [Parameter(Mandatory)]
        [string]$IPAddress,

        [Parameter(Mandatory)]
        [string]$DefaultGateway,

        [Parameter(Mandatory)]
        [string[]]$DNSAddresses
    )
    # Set the hostname (will require a reboot)
    Rename-Computer -NewName $Hostname

    # Create a local administrator (will prompt for password) and disable the existing Administrator account
    New-LocalUser -Name $LocalAdministrator | Add-LocalGroupMember -Group "Administrators"
    Get-LocalUser "Administrator" | Disable-LocalUser

    # Enable automatic updates, schedule a day (every day), time (0300) and follow that schedule
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name ScheduledInstallDay -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name ScheduledInstallTime -Value 3
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name AUOptions -Value 4

    # Enable remote desktop and require Network Level Authentication (NLA)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1

    # Set the timezone
    Set-TimeZone -Id $TimeZone

    # Label and set up disk volumes
    Set-Volume -DriveLetter C -NewFileSystemLabel $OSDriveLabel

    # WARNING: This is highly specific to my set up as I have a second disk I use for storage
    #Get-Disk -FriendlyName "Apple*" | New-Partition -UseMaximumSize -DriveLetter D | Format-Volume -FileSystem NTFS -NewFileSystemLabel "STORAGE"

    # Download and install Windows Admin Center - Only if you want to administrate via HTTP(s)
    # INFO: You generally only need to install this on one server to rule them all
    #Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/p/?linkid=2194936" -Destination "C:\Windows\Temp\WindowsAdminCenter.msi"
    #msiexec /i C:\Windows\Temp\WindowsAdminCenter.msi /qn /L*v C:\Windows\Temp\WindowsAdminCenter.log SME_PORT=443 SSL_CERTIFICATE_OPTION=generate

    # Enable incoming ICMP (ping)
    New-NetFirewallRule -DisplayName "Networking - Echo Request (ICMPv4-In)" -Direction Inbound -Action Allow -Enabled True -Profile Public -Protocol "ICMPv4" -IcmpType 8 -Group "File and Printer Sharing"
    New-NetFirewallRule -DisplayName "Networking - Echo Request (ICMPv6-In)" -Direction Inbound -Action Allow -Enabled True -Profile Public -Protocol "ICMPv6" -IcmpType 128 -Group "File and Printer Sharing"

    # Confirm InterfaceIndex/InterfaceAlias to make sure the correct interface adapter is being set
    $Interface = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4
    $Interface | New-NetIPAddress -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $DefaultGateway
    $Interface | Set-DnsClientServerAddress -ServerAddresses $DNSAddress
}

function New-MSSADomain {
    # Need to install Active Directory Domain Services before we have access to the AD PowerShell modules
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    # Just in case it is not already imported
    Import-Module ADDSDeployment

    # Many of these values are default but the big ones are -DomainName and -DomainNetBiosName
    Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "WinThreshold" -DomainName "mssa.cammarata.me" -DomainNetbiosName "MSSA" -ForestMode "WinThreshold" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true
}

function New-MSSAVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Parameter(ValueFromPipeline)]
        [string]$VMName,

        [Int64]$MemorySize = 4GB,

        [Int64]$StorageSize = 100GB
    )

    begin {
        if (-not (Get-VMSwitch -Name "External Virtual Switch" -ErrorAction SilentlyContinue)) {
            Write-Host "Creating new internal switch called External Virtual Switch" -ForegroundColor Green
            New-VMSwitch -Name "External Virtual Switch" -NetAdapterName "Ethernet"
        }
    }

    process {
        # If the Virtual Machine already exists, kill the script; Names should be unique
        $VM = If (Get-VM $VMName -ErrorAction SilentlyContinue) {
            Write-Error "Virtual Machine with name $VMName already exists."
            Exit
        } else {
            New-VM -Name $VMName -Path "D:\Hyper-V" -NewVHDPath "$VMName.vhdx" -NewVHDSizeBytes $StorageSize -MemoryStartupBytes $MemorySize -Generation 2
        }

        # Get and connecte the External Virtual Switch to the VM
        $VMSwitch = Get-VMSwitch -Name "External Virtual Switch"
        Connect-VMNetworkAdapter -VMName $VM.Name -Name "Network Adapter" -SwitchName $VMSwitch.Name

        # Set the processor count to 4 as the lab environment has 8 cores overall
        Set-VMProcessor -VM $VM -Count 4

        # Enabled dynamic memory as much of the time the server will not need the full amount
        Set-VMMemory -VM $VM -DynamicMemoryEnabled $true

        # Attach boot ISO
        Add-VMDvdDrive -VM $VM -Path "D:\ISOs\WS2022.iso"
        Set-VMFirmware -VM $VM -FirstBootDevice (Get-VMDvdDrive -VM $VM)
    }
}

Export-ModuleMember -Function New-MSSAVM, Invoke-MSSAPostInstall