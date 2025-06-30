#Requires -Modules GroupPolicy
<#
.SYNOPSIS
    GPO Export Tool

.PARAMETER GPONames
    Namen der zu exportierenden GPOs (kommasepariert)

.PARAMETER BackupPath
    Pfad für den GPO-Export

.EXAMPLE
    .\GPO-Export-Tool.ps1 -GPONames "Default Domain Policy" -BackupPath "C:\GPO-Backups"
    .\GPO-Export-Tool.ps1 -GPONames "Policy1,Policy2" -BackupPath "C:\GPO-Backups"
#>

param(
    [string]$GPONames,
    [string]$BackupPath
)

Clear-Host
Write-Host -ForegroundColor Green "`n       ╔════════════════════════════════════════════════════════════════════════════╗"
Write-Host -ForegroundColor Green "       ║                                GPO-Tool: EXPORT                            ║"
Write-Host -ForegroundColor Green "       ╚════════════════════════════════════════════════════════════════════════════╝ `n"

# Parameter validieren - beide müssen zusammen angegeben werden
if (($GPONames -and -not $BackupPath) -or (-not $GPONames -and $BackupPath)) {
    Write-Host "`nFEHLER: Beide Parameter müssen zusammen angegeben werden!" -ForegroundColor Red
    Write-Host "`nVerwendung:" -ForegroundColor Yellow
    Write-Host "  Interaktiv:  .\GPO-Export-Tool.ps1" -ForegroundColor White
    Write-Host "  Parameter:   .\GPO-Export-Tool.ps1 -GPONames `"Name1,Name2`" -BackupPath `"C:\Pfad`"" -ForegroundColor White
    exit 1
}

# Modul laden
Import-Module GroupPolicy -ErrorAction Stop

# Alle GPOs laden
$AllGPOs = Get-GPO -All | Sort-Object DisplayName
Write-Host "Gefunden: $($AllGPOs.Count) GPOs" -ForegroundColor Green

# Parameter-Modus oder Interaktiv
if ($GPONames -and $BackupPath) {
    # Parameter-Modus: GPOs nach Namen suchen
    $RequestedNames = $GPONames.Split(',') | ForEach-Object { $_.Trim() }
    $SelectedGPOs = @()
    
    foreach ($Name in $RequestedNames) {
        $GPO = $AllGPOs | Where-Object { $_.DisplayName -eq $Name }
        if ($GPO) {
            $SelectedGPOs += $GPO
        } else {
            Write-Host "GPO nicht gefunden: $Name" -ForegroundColor Red
        }
    }
    
    if ($SelectedGPOs.Count -eq 0) {
        Write-Host "Keine gültigen GPOs gefunden!" -ForegroundColor Red
        exit 1
    }
} else {
    # Interaktiver Modus
    Write-Host "`n=== Verfügbare GPOs ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $AllGPOs.Count; $i++) {
        Write-Host "$($i + 1). $($AllGPOs[$i].DisplayName)"
    }
    
    do {
        $Input = Read-Host "`nNummer(n) der GPOs (kommasepariert, z.B. 1,3,5)"
        $Numbers = $Input.Split(',') | ForEach-Object { [int]$_.Trim() }
        $Valid = $true
        
        foreach ($Num in $Numbers) {
            if ($Num -lt 1 -or $Num -gt $AllGPOs.Count) {
                Write-Host "Ungültige Nummer: $Num" -ForegroundColor Red
                $Valid = $false
                break
            }
        }
    } while (-not $Valid)
    
    $SelectedGPOs = @()
    foreach ($Num in $Numbers) {
        $SelectedGPOs += $AllGPOs[$Num - 1]
    }
    
    # Auswahl anzeigen
    Write-Host "`n=== Ausgewählte GPOs ===" -ForegroundColor Cyan
    $SelectedGPOs | ForEach-Object { Write-Host "- $($_.DisplayName)" }
    
    $Confirm = Read-Host "`nExportieren? (J/N)"
    if ($Confirm -notmatch '^[JjYy]') {
        Write-Host "Abgebrochen" -ForegroundColor Yellow
        exit 0
    }
    
    if (-not $BackupPath) {
        $BackupPath = Read-Host "Exportpfad"
    }
}

# Pfad erstellen
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    Write-Host "Verzeichnis erstellt: $BackupPath" -ForegroundColor Green
}

# Export
Write-Host "`n=== Export startet ===" -ForegroundColor Green
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $BackupPath "GPO-ID-zu-Namen-Legende.log"
$LogEntries = @()
$Success = 0
$Errors = 0

foreach ($GPO in $SelectedGPOs) {
    Write-Host "Exportiere: $($GPO.DisplayName)..." -ForegroundColor Yellow
    
    try {
        $Result = Backup-GPO -Name $GPO.DisplayName -Path $BackupPath -Comment "Backup/Export von $($GPO.DisplayName) am $Timestamp"
        $LogEntries += "$Timestamp - $($GPO.Id.ToString()) - $($GPO.DisplayName)"
        Write-Host "  ✓ Erfolg (ID: $($Result.Id))" -ForegroundColor Green
        $Success++
    } catch {
        Write-Host "  ✗ Fehler: $($_.Exception.Message)" -ForegroundColor Red
        $Errors++
    }
}

# Log schreiben
if ($LogEntries.Count -gt 0) {
    if (Test-Path $LogFile) {
        $LogEntries | Add-Content -Path $LogFile -Encoding utf8
    } else {
        $LogEntries | Out-File -FilePath $LogFile -Encoding utf8
    }
}

# Zusammenfassung
Write-Host "`n=== Fertig ===" -ForegroundColor Green
Write-Host "Erfolgreich: $Success" -ForegroundColor Green
if ($Errors -gt 0) { Write-Host "Fehler: $Errors" -ForegroundColor Red }
Write-Host "Pfad: $BackupPath" -ForegroundColor Cyan

if (-not ($GPONames -and $BackupPath)) {
    Read-Host "`nEnter zum Beenden"
}
