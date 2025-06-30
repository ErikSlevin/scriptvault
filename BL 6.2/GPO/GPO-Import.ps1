#Requires -Modules GroupPolicy
<#
.SYNOPSIS
    GPO Import Tool

.PARAMETER ImportPath
    Pfad zu den GPO-Backups

.PARAMETER GPONames
    Namen der zu importierenden GPOs (kommasepariert, optional - wenn nicht angegeben werden alle verfügbaren angezeigt)

.EXAMPLE
    .\GPO-Import-Tool.ps1
    .\GPO-Import-Tool.ps1 -ImportPath "C:\GPO-Backups"
    .\GPO-Import-Tool.ps1 -ImportPath "C:\GPO-Backups" -GPONames "Default Domain Policy,Custom Policy"
#>

param(
    [string]$ImportPath,
    [string]$GPONames
)


cLEAR-HOST
Write-Host -ForegroundColor Green "`n       ╔════════════════════════════════════════════════════════════════════════════╗"
Write-Host -ForegroundColor Green "       ║                                GPO-Tool: IMPORT                            ║"
Write-Host -ForegroundColor Green "       ╚════════════════════════════════════════════════════════════════════════════╝ `n"

# Parameter validieren - ImportPath kann auch interaktiv abgefragt werden
if (-not $ImportPath) {
    if ($GPONames) {
        Write-Host "`nFEHLER: Wenn GPONames angegeben wird, muss auch ImportPath angegeben werden!" -ForegroundColor Red
        Write-Host "`nVerwendung:" -ForegroundColor Yellow
        Write-Host "  Komplett interaktiv:  .\GPO-Import-Tool.ps1" -ForegroundColor White
        Write-Host "  Mit Pfad:             .\GPO-Import-Tool.ps1 -ImportPath `"C:\GPO-Backups`"" -ForegroundColor White
        Write-Host "  Mit Parametern:       .\GPO-Import-Tool.ps1 -ImportPath `"C:\GPO-Backups`" -GPONames `"Name1,Name2`"" -ForegroundColor White
        exit 1
    }
    
    # Interaktiv nach Pfad fragen
    $ImportPath = Read-Host "Pfad zu den GPO-Backups"
    if (-not $ImportPath) {
        Write-Host "Abgebrochen - kein Pfad angegeben" -ForegroundColor Yellow
        exit 0
    }
}

# Pfad prüfen
if (-not (Test-Path $ImportPath)) {
    Write-Host "FEHLER: Pfad nicht gefunden: $ImportPath" -ForegroundColor Red
    exit 1
}

# Modul laden
try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Host "FEHLER: GroupPolicy-Modul konnte nicht geladen werden: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verfügbare Backup-Ordner einlesen
Write-Host "Suche nach GPO-Backup-Ordnern in: $ImportPath" -ForegroundColor Cyan
$BackupFolders = Get-ChildItem -Path $ImportPath -Directory

if ($BackupFolders.Count -eq 0) {
    Write-Host "Keine Ordner gefunden!" -ForegroundColor Red
    exit 1
}

Write-Host "Gefunden: $($BackupFolders.Count) Ordner" -ForegroundColor Green

# Jeden Ordner analysieren und GPO-Informationen extrahieren
$AvailableGPOs = @()
Write-Host "`nAnalysiere Backup-Ordner..." -ForegroundColor Yellow

foreach ($Folder in $BackupFolders) {
    try {
        # Suche nach Backup.xml in dem Ordner
        $BackupXmlPath = Join-Path $Folder.FullName "Backup.xml"
        
        if (Test-Path $BackupXmlPath) {
            # Lade Backup.xml
            [xml]$BackupXml = Get-Content $BackupXmlPath -Encoding UTF8
            
            # Extrahiere Informationen
            $DisplayName = $null
            $BackupTime = $null
            $GPOId = $null
            
            if ($BackupXml.GroupPolicyBackupScheme) {
                $DisplayNameNode = $BackupXml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName
                $BackupTimeNode = $BackupXml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.CreatedTime
                $GPOIdNode = $BackupXml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.ID
                
                # Extrahiere Text mit InnerText oder InnerXml
                if ($DisplayNameNode) {
                    $DisplayName = if ($DisplayNameNode.InnerText) { $DisplayNameNode.InnerText } else { $DisplayNameNode.InnerXml }
                }
                if ($BackupTimeNode) {
                    $BackupTime = if ($BackupTimeNode.InnerText) { $BackupTimeNode.InnerText } else { $BackupTimeNode.InnerXml }
                }
                if ($GPOIdNode) {
                    $GPOId = if ($GPOIdNode.InnerText) { $GPOIdNode.InnerText } else { $GPOIdNode.InnerXml }
                }
            }
            
            if ($DisplayName) {
                $GPOInfo = [PSCustomObject]@{
                    BackupId = $Folder.Name
                    DisplayName = $DisplayName
                    BackupTime = if ($BackupTime) { [DateTime]::Parse($BackupTime) } else { $Folder.LastWriteTime }
                    GPOId = if ($GPOId) { $GPOId } else { $Folder.Name }
                    FolderPath = $Folder.FullName
                }
                $AvailableGPOs += $GPOInfo
                Write-Host "  ✓ $DisplayName" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $($Folder.Name) - DisplayName nicht gefunden" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ $($Folder.Name) - Keine Backup.xml gefunden" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ $($Folder.Name) - Fehler: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($AvailableGPOs.Count -eq 0) {
    Write-Host "`nKeine gültigen GPO-Backups gefunden!" -ForegroundColor Red
    exit 1
}

# GPOs nach Backup-Zeit sortieren (neueste zuerst)
$AvailableGPOs = $AvailableGPOs | Sort-Object BackupTime -Descending

# Parameter-Modus oder Interaktiv
if ($GPONames) {
    # Parameter-Modus: GPOs nach Namen filtern
    $RequestedNames = $GPONames.Split(',') | ForEach-Object { $_.Trim() }
    $SelectedGPOs = @()
    
    foreach ($Name in $RequestedNames) {
        $GPO = $AvailableGPOs | Where-Object { $_.DisplayName -eq $Name }
        if ($GPO) {
            $SelectedGPOs += $GPO
        } else {
            Write-Host "GPO-Backup nicht gefunden: $Name" -ForegroundColor Red
        }
    }
    
    if ($SelectedGPOs.Count -eq 0) {
        Write-Host "Keine gültigen GPO-Backups gefunden!" -ForegroundColor Red
        exit 1
    }
} else {
    # Interaktiver Modus
    Write-Host "`n=== Verfügbare GPO-Backups (neueste zuerst) ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $AvailableGPOs.Count; $i++) {
        $GPO = $AvailableGPOs[$i]
        Write-Host "$($i + 1). $($GPO.DisplayName)" -ForegroundColor White
        Write-Host "   Backup-Zeit: $($GPO.BackupTime)" -ForegroundColor Gray
        Write-Host ""
    }
    
    do {
        $Input = Read-Host "Nummer(n) der zu importierenden GPOs (kommasepariert, z.B. 1,3,5)"
        $Numbers = $Input.Split(',') | ForEach-Object { [int]$_.Trim() }
        $Valid = $true
        
        foreach ($Num in $Numbers) {
            if ($Num -lt 1 -or $Num -gt $AvailableGPOs.Count) {
                Write-Host "Ungültige Nummer: $Num" -ForegroundColor Red
                $Valid = $false
                break
            }
        }
    } while (-not $Valid)
    
    $SelectedGPOs = @()
    foreach ($Num in $Numbers) {
        $SelectedGPOs += $AvailableGPOs[$Num - 1]
    }
    
    # Auswahl anzeigen
    Write-Host "`n=== Ausgewählte GPOs für Import ===" -ForegroundColor Cyan
    $SelectedGPOs | ForEach-Object { 
        Write-Host "- $($_.DisplayName)" -ForegroundColor White
    }
    
    $Confirm = Read-Host "`nImportieren? (J/N)"
    if ($Confirm -notmatch '^[JjYy]') {
        Write-Host "Abgebrochen" -ForegroundColor Yellow
        exit 0
    }
}

# Import durchführen
Write-Host "`n=== Import startet ===" -ForegroundColor Green
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ImportLogFile = Join-Path $ImportPath "GPO-Import-Log.log"
$ImportLogEntries = @()
$Success = 0
$Errors = 0

foreach ($GPOInfo in $SelectedGPOs) {
    Write-Host "Importiere: $($GPOInfo.DisplayName)..." -ForegroundColor Yellow
    
    try {
        # GPO importieren
        Import-GPO `
            -BackupId $GPOInfo.BackupId `
            -TargetName $GPOInfo.DisplayName `
            -Path $ImportPath `
            -Domain $env:USERDNSDOMAIN `
            -CreateIfNeeded
        
        $LogEntry = "$Timestamp - ERFOLG - $($GPOInfo.DisplayName) - BackupId: $($GPOInfo.BackupId)"
        $ImportLogEntries += $LogEntry
        Write-Host "  ✓ Erfolg" -ForegroundColor Green
        $Success++
        
    } catch {
        $ErrorMsg = $_.Exception.Message
        $LogEntry = "$Timestamp - FEHLER - $($GPOInfo.DisplayName) - BackupId: $($GPOInfo.BackupId) - Fehler: $ErrorMsg"
        $ImportLogEntries += $LogEntry
        Write-Host "  ✗ Fehler: $ErrorMsg" -ForegroundColor Red
        $Errors++
    }
}

# Import-Log schreiben
if ($ImportLogEntries.Count -gt 0) {
    $ImportLogEntries | Out-File -FilePath $ImportLogFile -Encoding utf8
    Write-Host "`nImport-Log erstellt: $ImportLogFile" -ForegroundColor Cyan
}

# Zusammenfassung
Write-Host "`n=== Import abgeschlossen ===" -ForegroundColor Green
Write-Host "Erfolgreich importiert: $Success" -ForegroundColor Green
if ($Errors -gt 0) { 
    Write-Host "Fehler: $Errors" -ForegroundColor Red 
    Write-Host "Details siehe: $ImportLogFile" -ForegroundColor Yellow
}
Write-Host "Domain: $env:USERDNSDOMAIN" -ForegroundColor Cyan

if (-not $GPONames) {
    Read-Host "`nEnter zum Beenden"
}
