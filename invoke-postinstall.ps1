function Invoke-PostInstall {
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

Invoke-PostInstall -HostName "WS2022-DC" -LocalAdministrator "pcammarata" -InterfaceAlias "Ethernet" -IPAddress "192.168.42.11" -DefaultGateway "192.168.42.1" -DNSAddress "192.168.42.1"

Restart-Computer -Force
