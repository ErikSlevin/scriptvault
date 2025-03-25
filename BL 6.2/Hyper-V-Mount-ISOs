$isoPaths = @{
    "AiO.iso"                      = "D:\Service-ISOs\AiO.iso"
    "SQL_SRV_2017_RTM.iso"          = "D:\Service-ISOs\SQL_SRV_2017_RTM.iso"
    "LANcrypt.iso"                  = "D:\Service-ISOs\LANcrypt.iso"
    "Domino.iso"                    = "D:\Service-ISOs\Domino.iso"
    "itWESS.iso"                    = "D:\Service-ISOs\itWESS.iso"
    "Windows10_22H2.iso"            = "D:\Service-ISOs\Windows10_22H2.iso"
    "SEP_143_RU7.iso"               = "D:\Service-ISOs\SEP_143_RU7.iso"
    "SEP_DefinitionUpdates.iso"     = "D:\Service-ISOs\SEP_DefinitionUpdates.iso"
}

# Array für VMs und deren zugeordnete ISOs
$vmIsoMapping = @{
    "VM PROD DC 01"           = @("AiO.iso")
    "VM PROD DC 02"           = @("AiO.iso")
    "VM PROD FS 01"           = @("AiO.iso")
    "VM PROD FS 02"           = @("AiO.iso")
    "VM PROD WSUS 01"         = @("AiO.iso")
    "VM PROD LANCRYPT 01"     = @("AiO.iso", "SQL_SRV_2017_RTM.iso", "LANcrypt.iso")
    "VM PROD MAIL 01"         = @("AiO.iso")
    "VM PROD MAIL 02"         = @("AiO.iso", "Domino.iso")
    "VM PROD ITWATCH 01"      = @("AiO.iso", "itWESS.iso", "SQL_SRV_2017_RTM.iso")
    "VM PROD PRT 01"          = @("AiO.iso")
    "VM PROD DHCP 01"         = @("AiO.iso")
    "VM PROD WDS 01"          = @("AiO.iso", "Windows10_22H2.iso")
    "VM PROD WEB 01"          = @("AiO.iso")
    "VM PROD AV 01"           = @("AiO.iso", "SEP_143_RU7.iso", "SEP_DefinitionUpdates.iso")
}

# Funktion zur Zuordnung von ISOs zu DVD-Laufwerken
function Set-VDDrives {
    param (
        [string]$vmName,
        [array]$isoFiles,
        [array]$dvdDrives
    )

    # Durchlaufen aller ISO-Dateien und Zuweisung zu den entsprechenden DVD-Laufwerken
    for ($i = 0; $i -lt $isoFiles.Count; $i++) {
        if ($i -lt $dvdDrives.Count) {
            $dvdDrive = $dvdDrives[$i]
            Set-VMDVDDrive -VMName $vmName -Path $isoPaths[$isoFiles[$i]] -ControllerNumber $dvdDrive.ControllerNumber -ControllerLocation $dvdDrive.ControllerLocation
        }
    }
}

# Hauptlogik zum Zuweisen der ISOs
Get-VM | Where-Object { $_.Name -like "VM PROD*" } | ForEach-Object {
    $vm = $_
    $dvdDrives = Get-VMDVDDrive -VMName $vm.Name
    if ($dvdDrives) {
        $isoNames = $vmIsoMapping[$vm.Name]
        Set-VDDrives -vmName $vm.Name -isoFiles $isoNames -dvdDrives $dvdDrives

        Write-Host -NoNewline "$($vm.Name): "
        Write-Host -ForegroundColor Green ($isoNames -join ",")
    } else {
        Write-Host -ForegroundColor Red "ISO´s NICHT in $($vm.Name) eingebunden"
        Write-Host -ForegroundColor Red ($isoNames -join ",")
    }
}
