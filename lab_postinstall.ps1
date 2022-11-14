$Hostname = ""
$LocalAdministrator = ""

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

# Enable incoming ICMP (ping)
New-NetFirewallRule -DisplayName "Networking - Echo Request (ICMPv4-In)" -Direction Inbound -Action Allow -Enabled True -Profile Public -Protocol "ICMPv4" -IcmpType 8 -Group "File and Printer Sharing"
New-NetFirewallRule -DisplayName "Networking - Echo Request (ICMPv6-In)" -Direction Inbound -Action Allow -Enabled True -Profile Public -Protocol "ICMPv6" -IcmpType 128 -Group "File and Printer Sharing"

# Label and set up disk volumes
Set-Volume -DriveLetter C -NewFileSystemLabel "OS"
Get-Disk -FriendlyName "Apple*" | New-Partition -UseMaximumSize -DriveLetter D | Format-Volume -FileSystem NTFS -NewFileSystemLabel "STORAGE"

# Download and install Windows Admin Center
Start-BitsTransfer -Source https://go.microsoft.com/fwlink/p/?linkid=2194936 -Destination WindowsAdminCenter.msi
msiexec /i WindowsAdminCenter.msi /qn /L*v log.txt SME_PORT=443 SSL_CERTIFICATE_OPTION=generate
