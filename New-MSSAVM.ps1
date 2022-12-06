function New-MSSAVM {
    #[CmdletBinding()]
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
