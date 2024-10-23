# PS 0.2 v1.0 - Hyper-V installieren und konfigurieren


# 0. VM-Host-Einstellungen prüfen:
    $SB = {
      Get-VMHost 
     }
    $P = 'Name', 'V*Path','Numasp*', 'Ena*','RES*'
    Invoke-Command -Scriptblock $SB |  Format-Table -Property $P


# 1. Ggf die Rolle/Feature Hyper-V lokal installieren
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

# 2. Führen Sie einen Neustart aus:
    Restart-Computer -Force

# 4. Erstellen Sie die Ordner für die virtuellen Computer und die virtuellen Festplatten
#  und zeigen Sie die Ergebnisse an
    New-Item -Path F:\Vm -ItemType Directory -Force |
        Out-Null
    New-Item -Path F:\Vm\star.wars -ItemType Directory -Force |
        Out-Null
    Get-ChildItem -Path F:\Vm

# 5. Legen Sie die Standardpfade der virtuellen Computer und der virtuellen Festplatten
# von Hyper-V fest:
    $VMs  = 'F:\Vm\star.wars'
    $VHDs = 'F:\Vm\star.wars'
    Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VMs
    Set-VMHost -ComputerName Localhost -VirtualMachinePath $VHDs

# 6. Aktivieren Sie die Aufteilung auf NUMA 
    Set-VMHost -NumaSpanningEnabled $true

# 7. Aktivieren Sie den erweiterten Sitzungsmodus 
    Set-VMHost -EnableEnhancedSessionMode $true

# 8. Legen Sie das Intervall für die Ressourcenmessungen fest
    $RMInterval = New-TimeSpan -Hours 0 -Minutes 15
    Set-VMHost -ResourceMeteringSaveInterval $RMInterval




#---------------------------------------------------------------------------
# Falls Sie Hyper-V auf Dritthosts HV1, HV2 installieren möchten:
# von externem Client auszuführen:
#---------------------------------------------------------------------------
        
# 0a. VM-Hosts-Einstellungen prüfen:
    $S = New-PSSession HV1, HV2
    $SB = {
        Get-VMHost 
    }
    $P = 'Name', 'V*Path','Numasp*', 'Ena*','RES*'
    Invoke-Command -Scriptblock $SB -Session $S |
            Format-Table -Property $P

# 1a. Ggf die Rolle/Feature Hyper-V lokal installieren      
    $Sb = {
        Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
    }
    Invoke-Command -ComputerName HV1, HV2 -ScriptBlock $Sb

# 2a. Führen Sie einen Neustart beider Server aus, um die Installation abzuschlieÃŸen
    Restart-Computer -ComputerName HV1, HV2 -Force 

# 3a. Erstellen Sie  (nach dem Neustart)  eine PowerShell-Sitzung auf beiden HV-Servern 
    $S = New-PSSession HV1, HV2

# 4a. Erstellen Sie auf HV1 und HV2 die Ordner für die virtuellen Computer und die virtuellen Festplatten
#  und zeigen Sie die Ergebnisse an
    $Sb = {
        New-Item -Path C:\Vm -ItemType Directory -Force |
            Out-Null
        New-Item -Path C:\Vm\Vhds -ItemType Directory -Force |
            Out-Null
        New-Item -Path C:\Vm\VMs -ItemType Directory -force |
            Out-Null
        Get-ChildItem -Path C:\Vm }
    Invoke-Command -ScriptBlock $Sb -Session $S

# 5a. Legen Sie die Standardpfade der virtuellen Computer und der virtuellen Festplatten
# von Hyper-V fest
    $SB = {
      $VMs  = 'C:\Vm\Vhds'
      $VHDs = 'C:\Vm\VMs\Managing Hyper-V'
      Set-VMHost -ComputerName Localhost -VirtualHardDiskPath $VMs
      Set-VMHost -ComputerName Localhost -VirtualMachinePath $VHDs
    }
    Invoke-Command -ScriptBlock $SB -Session $S

# 6a. Aktivieren Sie die Aufteilung auf NUMA 
    $SB = {
      Set-VMHost -NumaSpanningEnabled $true
    }
    Invoke-Command -ScriptBlock $SB -Session $S

# 7a. Aktivieren Sie den erweiterten Sitzungsmodus 
    $SB = {
     Set-VMHost -EnableEnhancedSessionMode $true
    }
    Invoke-Command -ScriptBlock $SB -Session $S

# 8a. Legen Sie das Intervall für die Ressourcenmessungen auf HV1 und HV2 fest
    $SB = {
     $RMInterval = New-TimeSpan -Hours 0 -Minutes 15
      Set-VMHost -ResourceMeteringSaveInterval $RMInterval
    }
    Invoke-Command -ScriptBlock $SB -Session $S