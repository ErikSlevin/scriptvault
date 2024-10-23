# PS 0.3 v1.0 - VMs erstellen

#----------------------------------------------------------
# Client
#----------------------------------------------------------

# 0. Legen Sie den Namen der VM und die Pfade fest:
    $VMname      = 'Client.star.wars'
    $VMLocation  = "F:\Vm\star.wars\$VMname"
    $VHDlocation = 'F:\Vm\star.wars\$VMname'
    $Masterplatte = 'F:\Vm\W10Base.vhdx'
    $VhdPath = "$VMLocation\$VMname.vhdx"
    $startupbytes = 1GB
    $VMSwitch = "Internal Network"
    $ISOPath  = 'F:\Vm\de_windows_10_business_editions_version_2004_updated_oct_2020_x64_dvd_c726ed90.iso'

# 1. Erstellen Sie ein Verzeichnis für die VM:
    New-Item -Path "$VMLocation" -ItemType Directory -Force | Out-Null

# 2. HyperV initialisieren
    Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VHDlocation
    Set-VMHost -ComputerName Localhost -VirtualMachinePath $VMLocation

# 3. Erstellen Sie eine virtuelle Festplatte für die VM:
    New-VHD -ParentPath $Masterplatte -Path "$VhdPath" -Differencing  | Out-Null

# 4.    Erstellen Sie eine neue VM:
    new-vm -vmname $VMname -Generation 2  -memorystartupbytes $startupbytes

# 5. Fügen Sie der VM die virtuelle Festplatte hinzu:
    add-vmharddiskdrive -vmname $VMname -path "$VhdPath"

# 6. Verbinden Sie die NW Karte der VM:
    Get-VMSwitch $VMSwitch | Connect-VMNetworkAdapter -VMName $vmname

# 7. Starten Sie die VM:
    Start-VM -VMname $VMname 

# 8. Zeigen Sie die Ergebnisse an:
    Get-VM -Name $VMname

#----------------------------------------------------------
# DC1
#----------------------------------------------------------

# 0. Legen Sie den Namen der VM und die Pfade fest:
    $VMname      = 'DC1.star.wars'
    $VMLocation  = "F:\Vm\star.wars\$VMname"
    $VHDlocation = 'F:\Vm\star.wars\$VMname'
    $Masterplatte = 'F:\Vm\WS16Master.vhdx'
    $VhdPath = "$VMLocation\$VMname.vhdx"
    $startupbytes = 2GB
    $VMSwitch = "Internal Network"
    $ISOPath  = 'F:\Vm\de_windows_10_business_editions_version_2004_updated_oct_2020_x64_dvd_c726ed90.iso'

# 1. Erstellen Sie ein Verzeichnis für die VM:
    New-Item -Path "$VMLocation" -ItemType Directory -Force | Out-Null

# 2. HyperV initialisieren
    Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VHDlocation
    Set-VMHost -ComputerName Localhost -VirtualMachinePath $VMLocation

# 3. Erstellen Sie eine virtuelle Festplatte für die VM:
    New-VHD -ParentPath $Masterplatte -Path "$VhdPath" -Differencing  | Out-Null

# 4.    Erstellen Sie eine neue VM:
    new-vm -vmname $VMname -Generation 2  -memorystartupbytes $startupbytes

# 5. Fügen Sie der VM die virtuelle Festplatte hinzu:
    add-vmharddiskdrive -vmname $VMname -path "$VhdPath"

# 6. Verbinden Sie die NW Karte der VM:
    Get-VMSwitch $VMSwitch | Connect-VMNetworkAdapter -VMName $vmname

# 7. Starten Sie die VM:
    Start-VM -VMname $VMname 

# 8. Zeigen Sie die Ergebnisse an:
    Get-VM -Name $VMname


#----------------------------------------------------------
# DC2
#----------------------------------------------------------

# 0. Legen Sie den Namen der VM und die Pfade fest:
    $VMname      = 'DC2.star.wars'
    $VMLocation  = "F:\Vm\star.wars\$VMname"
    $VHDlocation = 'F:\Vm\star.wars\$VMname'
    $Masterplatte = 'F:\Vm\WS16CoreMaster.vhdx'
    $VhdPath = "$VMLocation\$VMname.vhdx"
    $startupbytes = 2GB
    $VMSwitch = "Internal Network"
    $ISOPath  = 'F:\Vm\de_windows_10_business_editions_version_2004_updated_oct_2020_x64_dvd_c726ed90.iso'

# 1. Erstellen Sie ein Verzeichnis für die VM:
    New-Item -Path "$VMLocation" -ItemType Directory -Force | Out-Null

# 2. HyperV initialisieren
    Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VHDlocation
    Set-VMHost -ComputerName Localhost -VirtualMachinePath $VMLocation

# 3. Erstellen Sie eine virtuelle Festplatte für die VM:
    New-VHD -ParentPath $Masterplatte -Path "$VhdPath" -Differencing  | Out-Null

# 4.    Erstellen Sie eine neue VM:
    new-vm -vmname $VMname -Generation 2  -memorystartupbytes $startupbytes

# 5. Fügen Sie der VM die virtuelle Festplatte hinzu:
    add-vmharddiskdrive -vmname $VMname -path "$VhdPath"

# 6. Verbinden Sie die NW Karte der VM:
    Get-VMSwitch $VMSwitch | Connect-VMNetworkAdapter -VMName $vmname

# 7. Starten Sie die VM:
    Start-VM -VMname $VMname 

# 8. Zeigen Sie die Ergebnisse an:
    Get-VM -Name $VMname



#----------------------------------------------------------
# FileServer
#----------------------------------------------------------

# 0. Legen Sie den Namen der VM und die Pfade fest:
    $VMname      = 'FileServer.star.wars'
    $VMLocation  = "F:\Vm\star.wars\$VMname"
    $VHDlocation = 'F:\Vm\star.wars\$VMname'
    $Masterplatte = 'F:\Vm\WS16CoreMaster.vhdx'
    $VhdPath = "$VMLocation\$VMname.vhdx"
    $startupbytes = 2GB
    $VMSwitch = "Internal Network"
    $ISOPath  = 'F:\Vm\de_windows_10_business_editions_version_2004_updated_oct_2020_x64_dvd_c726ed90.iso'

# 1. Erstellen Sie ein Verzeichnis für die VM:
    New-Item -Path "$VMLocation" -ItemType Directory -Force | Out-Null

# 2. HyperV initialisieren
    Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VHDlocation
    Set-VMHost -ComputerName Localhost -VirtualMachinePath $VMLocation

# 3. Erstellen Sie eine virtuelle Festplatte für die VM:
    New-VHD -ParentPath $Masterplatte -Path "$VhdPath" -Differencing  | Out-Null

# 4.    Erstellen Sie eine neue VM:
    new-vm -vmname $VMname -Generation 2  -memorystartupbytes $startupbytes

# 5. Fügen Sie der VM die virtuelle Festplatte hinzu:
    add-vmharddiskdrive -vmname $VMname -path "$VhdPath"

# 6. Verbinden Sie die NW Karte der VM:
    Get-VMSwitch $VMSwitch | Connect-VMNetworkAdapter -VMName $vmname

# 7. Starten Sie die VM:
    Start-VM -VMname $VMname 

# 8. Zeigen Sie die Ergebnisse an:
    Get-VM -Name $VMname


