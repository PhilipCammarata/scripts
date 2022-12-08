function New-MSSAVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
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
            Write-Host "Creating new Virtual Machine called $VMName with $([math]::round($MemorySize/1GB, 2))GB memory and a $([math]::round($StorageSize/1GB, 2))GB VHDX." -ForegroundColor Green
            New-VM -Name $VMName -Path "D:\Hyper-V" -NewVHDPath "$VMName.vhdx" -NewVHDSizeBytes $StorageSize -MemoryStartupBytes $MemorySize -Generation 2 -ErrorAction Stop
        }

        # Get and connecte the External Virtual Switch to the VM
        $VMSwitch = Get-VMSwitch -Name "External Virtual Switch"
        Write-Host "Attaching $($VMSwitch.Name) to $VMName." -ForegroundColor Green
        Connect-VMNetworkAdapter -VMName $VM.Name -Name "Network Adapter" -SwitchName $VMSwitch.Name

        # Set the processor count to 4 as the lab environment has 8 cores overall
        Write-Host "Setting the processor count to 4 for $VMName" -ForegroundColor Green
        Set-VMProcessor -VM $VM -Count 4

        # Enabled dynamic memory as much of the time the server will not need the full amount
        Write-Host "Enabling Dynamic Memory for $VMName" -ForegroundColor Green
        Set-VMMemory -VM $VM -DynamicMemoryEnabled $true

        # Attach boot ISO
        Add-VMDvdDrive -VM $VM -Path "D:\ISOs\WS2022.iso"
        Set-VMFirmware -VM $VM -FirstBootDevice (Get-VMDvdDrive -VM $VM)
    }
}

$NewServers = @("WS2022-SERVER1", "WS2022-SERVER2", "WS2022-SERVER3")

$NewServers | New-MSSAVM

#Invoke-Command -FilePath .\New-MSSAVM.ps1 -ComputerName OCTOPUS
