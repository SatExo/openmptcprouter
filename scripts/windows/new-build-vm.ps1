<#
.SYNOPSIS
    Creates the Hyper-V virtual machine "hyperg-build" that builds HyperG images.
.DESCRIPTION
    Run once, in an elevated PowerShell on the Windows 11 Pro build PC.
    The VM gets 6 vCPU, 10 GB RAM, a 200 GB dynamically expanding disk, nested
    virtualization (so the Linux guest has /dev/kvm for fast image boot tests)
    and starts automatically with Windows.
.EXAMPLE
    .\new-build-vm.ps1 -IsoPath C:\Users\me\Downloads\ubuntu-24.04.3-live-server-amd64.iso
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $IsoPath,

    [string] $VhdDir = 'C:\HyperG\vm'
)

$ErrorActionPreference = 'Stop'

$VmName       = 'hyperg-build'
$CpuCount     = 6
$MemoryBytes  = 10GB
$DiskBytes    = 200GB
$MinFreeBytes = 220GB
$SwitchName   = 'Default Switch'

$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($feature.State -ne 'Enabled') {
    throw 'Hyper-V is not enabled. Turn it on in "Turn Windows features on or off", reboot, and run this again.'
}
if (-not (Test-Path -LiteralPath $IsoPath)) {
    throw "Ubuntu ISO not found: $IsoPath"
}
if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
    throw "A VM named $VmName already exists. Remove it first or keep using it."
}

New-Item -ItemType Directory -Force -Path $VhdDir | Out-Null
$drive = (Get-Item -LiteralPath $VhdDir).PSDrive
if ($drive.Free -lt $MinFreeBytes) {
    throw ("Drive {0}: has {1:N0} GB free; at least {2:N0} GB needed." -f $drive.Name, ($drive.Free / 1GB), ($MinFreeBytes / 1GB))
}

$vhdPath = Join-Path $VhdDir "$VmName.vhdx"
New-VM -Name $VmName -Generation 2 -MemoryStartupBytes $MemoryBytes `
    -NewVHDPath $vhdPath -NewVHDSizeBytes $DiskBytes -SwitchName $SwitchName | Out-Null

Set-VM -Name $VmName -StaticMemory -ProcessorCount $CpuCount `
    -AutomaticStartAction Start -AutomaticStartDelay 60 -AutomaticStopAction ShutDown `
    -CheckpointType Disabled
Set-VMProcessor -VMName $VmName -ExposeVirtualizationExtensions $true
Set-VMFirmware -VMName $VmName -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

$dvd = Add-VMDvdDrive -VMName $VmName -Path $IsoPath -Passthru
Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd

Write-Host "VM $VmName created. Start it, connect from Hyper-V Manager and install Ubuntu Server"
Write-Host "(tick 'Install OpenSSH server', user 'hgbuild'). Then remove the ISO:"
Write-Host "  Get-VMDvdDrive -VMName $VmName | Set-VMDvdDrive -Path `$null"
