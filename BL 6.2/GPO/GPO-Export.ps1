#Requires -Version 5.1
#Requires -Modules GroupPolicy

<#
.SYNOPSIS
    Exportiert ausgewählte Group Policy Objects (GPOs) als Backup-Dateien.

.DESCRIPTION
    Dieses Tool ermöglicht den Export von GPOs entweder interaktiv oder über Parameter.
    Es erstellt strukturierte Backups mit detailliertem Logging und Metadaten.

.PARAMETER GpoNames
    Kommaseparierte Liste der zu exportierenden GPO-Namen.
    Wenn nicht angegeben, erfolgt eine interaktive Auswahl.

.PARAMETER BackupPath
    Zielpfad für die GPO-Backups. Muss ein gültiger Verzeichnispfad sein oder erstellt werden können.

.PARAMETER Mode
    Ausführungsmodus: 'Interactive' für Benutzerinteraktion oder 'Silent' für automatische Ausführung.

.EXAMPLE
    .\GPO-Export-Optimized.ps1
    Startet das Tool im interaktiven Modus.

.EXAMPLE
    .\GPO-Export-Optimized.ps1 -GpoNames "Default Domain Policy" -BackupPath "C:\GPO-Backups"
    Exportiert eine spezifische GPO in den angegebenen Pfad.

.EXAMPLE
    .\GPO-Export-Optimized.ps1 -GpoNames "Policy1,Policy2" -BackupPath "C:\GPO-Backups" -Mode Silent
    Exportiert mehrere GPOs ohne Benutzerinteraktion.

.NOTES
    Version: 2.0
    Autor: Erik Slevin
    Erstellt: 30.06.20255
    Benötigt: PowerShell 5.1+, GroupPolicy-Modul, Domain-Zugriff
#>

[CmdletBinding()]
param(
    [Parameter(
        Position = 0,
        HelpMessage = "Kommaseparierte Liste der GPO-Namen zum Export"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$GpoNames,

    [Parameter(
        Position = 1,
        HelpMessage = "Zielpfad für GPO-Backups"
    )]
    [ValidateScript({
        # Prüfung ob Pfad existiert oder erstellt werden kann
        if (Test-Path $_ -PathType Container) {
            return $true
        }
        # Versuche Elternverzeichnis zu finden
        $parentPath = Split-Path $_ -Parent
        if ([string]::IsNullOrEmpty($parentPath) -or (Test-Path $parentPath -PathType Container)) {
            return $true
        }
        throw "Der Pfad '$_' ist ungültig oder das Elternverzeichnis existiert nicht."
    })]
    [string]$BackupPath,

    [Parameter(
        HelpMessage = "Ausführungsmodus: Interactive oder Silent"
    )]
    [ValidateSet('Interactive', 'Silent')]
    [string]$Mode = 'Interactive'
)

#region Konstanten und Konfiguration
$Script:Config = @{
    LogFileName = 'GPO-Export-Metadata.log'
    DateTimeFormat = 'yyyy-MM-dd_HH-mm-ss'
    Encoding = 'UTF8'
    ConfirmationPattern = '^[JjYy]'
}

$Script:Messages = @{
    Title = "`n       ╔════════════════════════════════════════════════════════════════════════════╗`n       ║                                GPO-Tool: EXPORT                            ║`n       ╚════════════════════════════════════════════════════════════════════════════╝`n"
    GpoCountFound = "Gefundene GPOs in der Domäne: {0}"
    ExportStarting = "`n=== Export wird gestartet ==="
    ExportCompleted = "`n=== Export abgeschlossen ==="
    CreatedDirectory = "Verzeichnis wurde erstellt: {0}"
    ExportingGpo = "Exportiere GPO: {0}..."
    ExportSuccess = "  ✓ Erfolgreich exportiert (Backup-ID: {0})"
    ExportError = "  ✗ Export fehlgeschlagen: {0}"
    ValidationError = "FEHLER: {0}"
    UserCancelled = "Vorgang wurde vom Benutzer abgebrochen."
}
#endregion

#region Hilfsfunktionen für Präsentation
function Write-ToolHeader {
    <#
    .SYNOPSIS
        Zeigt den Tool-Header an.
    #>
    Clear-Host
    Write-Host $Script:Messages.Title -ForegroundColor Green
}

function Write-StatusMessage {
    <#
    .SYNOPSIS
        Zeigt formatierte Statusmeldungen an.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colorMap = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Type]
}

function Write-GpoList {
    <#
    .SYNOPSIS
        Zeigt eine nummerierte Liste von GPOs an.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Object[]]$GpoList,
        
        [string]$Title = "Verfügbare GPOs"
    )
    
    Write-StatusMessage "`n=== $Title ===" -Type Info
    
    for ($i = 0; $i -lt $GpoList.Count; $i++) {
        Write-Host "$($i + 1). $($GpoList[$i].DisplayName)" -ForegroundColor White
    }
}

function Write-ExportSummary {
    <#
    .SYNOPSIS
        Zeigt die Zusammenfassung des Exports an.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$SuccessCount,
        
        [Parameter(Mandatory)]
        [int]$ErrorCount,
        
        [Parameter(Mandatory)]
        [string]$ExportPath
    )
    
    Write-StatusMessage $Script:Messages.ExportCompleted -Type Success
    Write-StatusMessage "Erfolgreich exportiert: $SuccessCount" -Type Success
    
    if ($ErrorCount -gt 0) {
        Write-StatusMessage "Fehlgeschlagen: $ErrorCount" -Type Error
    }
    
    Write-StatusMessage "Exportpfad: $ExportPath" -Type Info
}
#endregion

#region Kernlogik-Funktionen
function Get-AllDomainGpos {
    <#
    .SYNOPSIS
        Lädt alle GPOs aus der aktuellen Domäne.
    #>
    try {
        Import-Module GroupPolicy -ErrorAction Stop
        $allGpos = Get-GPO -All | Sort-Object DisplayName
        
        Write-StatusMessage ($Script:Messages.GpoCountFound -f $allGpos.Count) -Type Success
        return $allGpos
    }
    catch {
        Write-StatusMessage ($Script:Messages.ValidationError -f "GroupPolicy-Modul konnte nicht geladen werden: $($_.Exception.Message)") -Type Error
        throw
    }
}

function Get-UserSelectedGpos {
    <#
    .SYNOPSIS
        Ermöglicht die interaktive Auswahl von GPOs durch den Benutzer.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Object[]]$AllGpos
    )
    
    Write-GpoList -GpoList $AllGpos
    
    do {
        $userInput = Read-Host "`nNummer(n) der zu exportierenden GPOs (kommasepariert, z.B. 1,3,5)"
        $selectedNumbers = $userInput.Split(',') | ForEach-Object { 
            $trimmed = $_.Trim()
            [int]$number = 0
            if ([int]::TryParse($trimmed, [ref]$number)) {
                $number
            }
        }
        
        $isValidSelection = $selectedNumbers | ForEach-Object {
            $_ -ge 1 -and $_ -le $AllGpos.Count
        }
        
        if ($isValidSelection -contains $false) {
            Write-StatusMessage "Ungültige Auswahl. Bitte wählen Sie Nummern zwischen 1 und $($AllGpos.Count)." -Type Warning
            $validInput = $false
        } else {
            $validInput = $true
        }
    } while (-not $validInput)
    
    # Ausgewählte GPOs zurückgeben
    $selectedGpos = $selectedNumbers | ForEach-Object { $AllGpos[$_ - 1] }
    
    # Auswahl bestätigen
    Write-GpoList -GpoList $selectedGpos -Title "Ausgewählte GPOs für Export"
    
    $confirmation = Read-Host "`nExport starten? (J/N)"
    if ($confirmation -notmatch $Script:Config.ConfirmationPattern) {
        Write-StatusMessage $Script:Messages.UserCancelled -Type Warning
        return $null
    }
    
    return $selectedGpos
}

function Get-GposByNames {
    <#
    .SYNOPSIS
        Sucht GPOs anhand ihrer Namen.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GpoNameList,
        
        [Parameter(Mandatory)]
        [System.Object[]]$AllGpos
    )
    
    $requestedNames = $GpoNameList.Split(',') | ForEach-Object { $_.Trim() }
    $foundGpos = @()
    $notFoundNames = @()
    
    foreach ($name in $requestedNames) {
        $matchingGpo = $AllGpos | Where-Object { $_.DisplayName -eq $name }
        if ($matchingGpo) {
            $foundGpos += $matchingGpo
        } else {
            $notFoundNames += $name
        }
    }
    
    # Fehlende GPOs melden
    if ($notFoundNames.Count -gt 0) {
        foreach ($name in $notFoundNames) {
            Write-StatusMessage "GPO nicht gefunden: $name" -Type Warning
        }
    }
    
    if ($foundGpos.Count -eq 0) {
        throw "Keine der angegebenen GPOs wurde gefunden."
    }
    
    return $foundGpos
}

function Initialize-BackupDirectory {
    <#
    .SYNOPSIS
        Erstellt das Backup-Verzeichnis falls es nicht existiert.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path -PathType Container)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-StatusMessage ($Script:Messages.CreatedDirectory -f $Path) -Type Success
        }
        catch {
            throw "Konnte Backup-Verzeichnis nicht erstellen: $($_.Exception.Message)"
        }
    }
    
    return (Resolve-Path $Path).Path
}

function Export-GpoBackups {
    <#
    .SYNOPSIS
        Führt den eigentlichen Export der ausgewählten GPOs durch.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Object[]]$GposToExport,
        
        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    
    Write-StatusMessage $Script:Messages.ExportStarting -Type Info
    
    $timestamp = Get-Date -Format $Script:Config.DateTimeFormat
    $logFilePath = Join-Path $TargetPath $Script:Config.LogFileName
    $logEntries = @()
    $successCount = 0
    $errorCount = 0
    
    foreach ($gpo in $GposToExport) {
        Write-StatusMessage ($Script:Messages.ExportingGpo -f $gpo.DisplayName) -Type Info
        
        try {
            $backupResult = Backup-GPO -Name $gpo.DisplayName -Path $TargetPath -Comment "Export von '$($gpo.DisplayName)' am $timestamp"
            
            # Erfolgreichen Export protokollieren
            $logEntry = "$timestamp - ERFOLG - GPO-ID: $($gpo.Id) - Name: $($gpo.DisplayName) - Backup-ID: $($backupResult.Id)"
            $logEntries += $logEntry
            
            Write-StatusMessage ($Script:Messages.ExportSuccess -f $backupResult.Id) -Type Success
            $successCount++
        }
        catch {
            # Fehlgeschlagenen Export protokollieren
            $errorMessage = $_.Exception.Message
            $logEntry = "$timestamp - FEHLER - GPO-ID: $($gpo.Id) - Name: $($gpo.DisplayName) - Fehler: $errorMessage"
            $logEntries += $logEntry
            
            Write-StatusMessage ($Script:Messages.ExportError -f $errorMessage) -Type Error
            $errorCount++
        }
    }
    
    # Log-Datei schreiben
    if ($logEntries.Count -gt 0) {
        try {
            if (Test-Path $logFilePath) {
                $logEntries | Add-Content -Path $logFilePath -Encoding $Script:Config.Encoding
            } else {
                $logEntries | Out-File -FilePath $logFilePath -Encoding $Script:Config.Encoding
            }
        }
        catch {
            Write-StatusMessage "Warnung: Log-Datei konnte nicht geschrieben werden: $($_.Exception.Message)" -Type Warning
        }
    }
    
    return @{
        SuccessCount = $successCount
        ErrorCount = $errorCount
    }
}

function Get-InteractiveBackupPath {
    <#
    .SYNOPSIS
        Fragt den Benutzer nach dem Backup-Pfad.
    #>
    do {
        $path = Read-Host "Pfad für GPO-Export eingeben"
        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-StatusMessage "Ungültiger Pfad. Bitte einen gültigen Pfad eingeben." -Type Warning
            $validPath = $false
        } else {
            $validPath = $true
        }
    } while (-not $validPath)
    
    return $path
}
#endregion

#region Hauptprogramm
function Start-GpoExportProcess {
    <#
    .SYNOPSIS
        Hauptfunktion zur Koordination des Export-Prozesses.
    #>
    try {
        Write-ToolHeader
        
        # Parametervalidierung
        if (($GpoNames -and -not $BackupPath) -or (-not $GpoNames -and $BackupPath)) {
            Write-StatusMessage "FEHLER: Wenn GPO-Namen angegeben werden, muss auch der Backup-Pfad angegeben werden!" -Type Error
            Write-StatusMessage "`nVerwendung:" -Type Info
            Write-StatusMessage "  Interaktiv:  .\GPO-Export-Optimized.ps1" -Type Info
            Write-StatusMessage "  Parameter:   .\GPO-Export-Optimized.ps1 -GpoNames `"Name1,Name2`" -BackupPath `"C:\Pfad`"" -Type Info
            exit 1
        }
        
        # Alle GPOs aus der Domäne laden
        $allGpos = Get-AllDomainGpos
        
        # GPOs für Export auswählen
        if ($GpoNames) {
            # Parameter-Modus: GPOs nach Namen suchen
            $selectedGpos = Get-GposByNames -GpoNameList $GpoNames -AllGpos $allGpos
        } else {
            # Interaktiver Modus: Benutzerauswahl
            $selectedGpos = Get-UserSelectedGpos -AllGpos $allGpos
            if ($null -eq $selectedGpos) {
                exit 0
            }
        }
        
        # Backup-Pfad bestimmen
        if (-not $BackupPath) {
            $BackupPath = Get-InteractiveBackupPath
        }
        
        # Backup-Verzeichnis vorbereiten
        $resolvedBackupPath = Initialize-BackupDirectory -Path $BackupPath
        
        # Export durchführen
        $exportResult = Export-GpoBackups -GposToExport $selectedGpos -TargetPath $resolvedBackupPath
        
        # Zusammenfassung anzeigen
        Write-ExportSummary -SuccessCount $exportResult.SuccessCount -ErrorCount $exportResult.ErrorCount -ExportPath $resolvedBackupPath
        
        # Bei interaktivem Modus auf Eingabe warten
        if ($Mode -eq 'Interactive') {
            Read-Host "`nDrücken Sie Enter zum Beenden"
        }
        
        exit 0
    }
    catch {
        Write-StatusMessage "Kritischer Fehler: $($_.Exception.Message)" -Type Error
        if ($Mode -eq 'Interactive') {
            Read-Host "`nDrücken Sie Enter zum Beenden"
        }
        exit 1
    }
}

# Hauptprogramm ausführen
Start-GpoExportProcess
#endregion
