#Requires -Version 5.1
#Requires -Modules GroupPolicy

<#
.SYNOPSIS
    Importiert Group Policy Objects (GPOs) aus Backup-Dateien.

.DESCRIPTION
    Dieses Tool ermöglicht den Import von GPO-Backups entweder interaktiv oder über Parameter.
    Es analysiert Backup-Verzeichnisse, extrahiert Metadaten und führt strukturierte Imports durch.

.PARAMETER ImportPath
    Pfad zu den GPO-Backup-Verzeichnissen. Muss ein gültiges Verzeichnis sein.

.PARAMETER GpoNames
    Kommaseparierte Liste der zu importierenden GPO-Namen.
    Wenn nicht angegeben, erfolgt eine interaktive Auswahl.

.PARAMETER Mode
    Ausführungsmodus: 'Interactive' für Benutzerinteraktion oder 'Silent' für automatische Ausführung.

.PARAMETER TargetDomain
    Zieldomäne für den Import. Wenn nicht angegeben, wird die aktuelle Domäne verwendet.

.EXAMPLE
    .\GPO-Import-Optimized.ps1
    Startet das Tool im interaktiven Modus.

.EXAMPLE
    .\GPO-Import-Optimized.ps1 -ImportPath "C:\GPO-Backups"
    Lädt Backups aus dem angegebenen Pfad und startet interaktive Auswahl.

.EXAMPLE
    .\GPO-Import-Optimized.ps1 -ImportPath "C:\GPO-Backups" -GpoNames "Default Domain Policy,Custom Policy"
    Importiert spezifische GPOs aus dem Backup-Pfad.

.NOTES
    Version: 2.0
    Autor: Erik Slevin
    Erstellt: 30.06.2025
    Benötigt: PowerShell 5.1+, GroupPolicy-Modul, Domain-Admin-Rechte
#>

[CmdletBinding()]
param(
    [Parameter(
        Position = 0,
        HelpMessage = "Pfad zu den GPO-Backup-Verzeichnissen"
    )]
    [ValidateScript({
        if (Test-Path $_ -PathType Container) {
            return $true
        }
        throw "Der Pfad '$_' existiert nicht oder ist kein Verzeichnis."
    })]
    [string]$ImportPath,

    [Parameter(
        Position = 1,
        HelpMessage = "Kommaseparierte Liste der zu importierenden GPO-Namen"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$GpoNames,

    [Parameter(
        HelpMessage = "Ausführungsmodus: Interactive oder Silent"
    )]
    [ValidateSet('Interactive', 'Silent')]
    [string]$Mode = 'Interactive',

    [Parameter(
        HelpMessage = "Zieldomäne für den Import"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$TargetDomain = $env:USERDNSDOMAIN
)

#region Konstanten und Konfiguration
$Script:Config = @{
    LogFileName = 'GPO-Import-Log.log'
    BackupXmlFileName = 'Backup.xml'
    DateTimeFormat = 'yyyy-MM-dd_HH-mm-ss'
    Encoding = 'UTF8'
    ConfirmationPattern = '^[JjYy]'
    MaxRetryAttempts = 3
}

$Script:Messages = @{
    Title = "`n       ╔════════════════════════════════════════════════════════════════════════════╗`n       ║                                GPO-Tool: IMPORT                            ║`n       ╚════════════════════════════════════════════════════════════════════════════╝`n"
    SearchingBackups = "Suche nach GPO-Backup-Verzeichnissen in: {0}"
    FoundDirectories = "Gefundene Verzeichnisse: {0}"
    AnalyzingBackups = "`nAnalysiere Backup-Verzeichnisse..."
    ImportStarting = "`n=== Import wird gestartet ==="
    ImportCompleted = "`n=== Import abgeschlossen ==="
    ImportingGpo = "Importiere GPO: {0}..."
    ImportSuccess = "  ✓ Erfolgreich importiert"
    ImportError = "  ✗ Import fehlgeschlagen: {0}"
    ValidationError = "FEHLER: {0}"
    UserCancelled = "Vorgang wurde vom Benutzer abgebrochen."
    NoValidBackups = "Keine gültigen GPO-Backups gefunden!"
    BackupAnalysisSuccess = "  ✓ {0}"
    BackupAnalysisWarning = "  ⚠ {0} - {1}"
    BackupAnalysisError = "  ✗ {0} - Fehler: {1}"
}

$Script:XmlNamespaces = @{
    BackupScheme = 'GroupPolicyBackupScheme'
    GpoObject = 'GroupPolicyObject'
    CoreSettings = 'GroupPolicyCoreSettings'
}
#endregion

#region Datenmodell
class GpoBackupInfo {
    [string]$BackupId
    [string]$DisplayName
    [datetime]$BackupTime
    [string]$GpoId
    [string]$FolderPath
    [string]$Comment
    [bool]$IsValid
    [string]$ErrorMessage
    
    GpoBackupInfo([string]$backupId, [string]$folderPath) {
        $this.BackupId = $backupId
        $this.FolderPath = $folderPath
        $this.IsValid = $false
    }
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

function Write-GpoBackupList {
    <#
    .SYNOPSIS
        Zeigt eine nummerierte Liste von GPO-Backups an.
    #>
    param(
        [Parameter(Mandatory)]
        [GpoBackupInfo[]]$BackupList,
        
        [string]$Title = "Verfügbare GPO-Backups (neueste zuerst)"
    )
    
    Write-StatusMessage "`n=== $Title ===" -Type Info
    
    for ($i = 0; $i -lt $BackupList.Count; $i++) {
        $backup = $BackupList[$i]
        Write-Host "$($i + 1). $($backup.DisplayName)" -ForegroundColor White
        Write-Host "   Backup-Zeit: $($backup.BackupTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "   Backup-ID: $($backup.BackupId)" -ForegroundColor Gray
        Write-Host ""
    }
}

function Write-ImportSummary {
    <#
    .SYNOPSIS
        Zeigt die Zusammenfassung des Imports an.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$SuccessCount,
        
        [Parameter(Mandatory)]
        [int]$ErrorCount,
        
        [Parameter(Mandatory)]
        [string]$Domain,
        
        [string]$LogFilePath
    )
    
    Write-StatusMessage $Script:Messages.ImportCompleted -Type Success
    Write-StatusMessage "Erfolgreich importiert: $SuccessCount" -Type Success
    
    if ($ErrorCount -gt 0) {
        Write-StatusMessage "Fehlgeschlagen: $ErrorCount" -Type Error
        if ($LogFilePath) {
            Write-StatusMessage "Details siehe Log-Datei: $LogFilePath" -Type Info
        }
    }
    
    Write-StatusMessage "Zieldomäne: $Domain" -Type Info
}
#endregion

#region XML-Verarbeitung
function Get-XmlNodeText {
    <#
    .SYNOPSIS
        Extrahiert sicher Text aus XML-Knoten.
    #>
    param(
        [System.Xml.XmlNode]$Node
    )
    
    if ($null -eq $Node) {
        return $null
    }
    
    # Versuche verschiedene Methoden zur Textextraktion
    if (-not [string]::IsNullOrEmpty($Node.InnerText)) {
        return $Node.InnerText.Trim()
    }
    elseif (-not [string]::IsNullOrEmpty($Node.InnerXml)) {
        return $Node.InnerXml.Trim()
    }
    elseif (-not [string]::IsNullOrEmpty($Node.'#text')) {
        return $Node.'#text'.Trim()
    }
    
    return $null
}

function Get-GpoBackupMetadata {
    <#
    .SYNOPSIS
        Extrahiert Metadaten aus einer GPO-Backup XML-Datei.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BackupXmlPath
    )
    
    try {
        [xml]$backupXml = Get-Content $BackupXmlPath -Encoding UTF8 -ErrorAction Stop
        
        if (-not $backupXml.($Script:XmlNamespaces.BackupScheme)) {
            throw "Ungültiges Backup.xml Format - GroupPolicyBackupScheme nicht gefunden"
        }
        
        $gpoObject = $backupXml.($Script:XmlNamespaces.BackupScheme).($Script:XmlNamespaces.GpoObject)
        if (-not $gpoObject) {
            throw "GroupPolicyObject-Sektion nicht gefunden"
        }
        
        $coreSettings = $gpoObject.($Script:XmlNamespaces.CoreSettings)
        if (-not $coreSettings) {
            throw "GroupPolicyCoreSettings-Sektion nicht gefunden"
        }
        
        # Metadaten extrahieren
        $displayName = Get-XmlNodeText -Node $coreSettings.DisplayName
        $createdTime = Get-XmlNodeText -Node $coreSettings.CreatedTime
        $gpoId = Get-XmlNodeText -Node $coreSettings.ID
        
        if ([string]::IsNullOrEmpty($displayName)) {
            throw "DisplayName konnte nicht extrahiert werden"
        }
        
        # Ergebnis-Objekt zurückgeben
        return @{
            DisplayName = $displayName
            CreatedTime = $createdTime
            GpoId = $gpoId
            IsValid = $true
            ErrorMessage = $null
        }
    }
    catch {
        return @{
            DisplayName = $null
            CreatedTime = $null
            GpoId = $null
            IsValid = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}
#endregion

#region Kernlogik-Funktionen
function Get-ImportPathFromUser {
    <#
    .SYNOPSIS
        Fragt den Benutzer nach dem Import-Pfad.
    #>
    do {
        $path = Read-Host "Pfad zu den GPO-Backups eingeben"
        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-StatusMessage "Ungültiger Pfad. Bitte einen gültigen Pfad eingeben." -Type Warning
            $validPath = $false
        }
        elseif (-not (Test-Path $path -PathType Container)) {
            Write-StatusMessage "Pfad existiert nicht: $path" -Type Warning
            $validPath = $false
        }
        else {
            $validPath = $true
        }
    } while (-not $validPath)
    
    return $path
}

function Get-GpoBackupDirectories {
    <#
    .SYNOPSIS
        Sucht und analysiert GPO-Backup-Verzeichnisse.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SearchPath
    )
    
    Write-StatusMessage ($Script:Messages.SearchingBackups -f $SearchPath) -Type Info
    
    # Backup-Verzeichnisse finden
    $backupDirectories = Get-ChildItem -Path $SearchPath -Directory -ErrorAction SilentlyContinue
    
    if ($backupDirectories.Count -eq 0) {
        throw "Keine Unterverzeichnisse im angegebenen Pfad gefunden."
    }
    
    Write-StatusMessage ($Script:Messages.FoundDirectories -f $backupDirectories.Count) -Type Success
    Write-StatusMessage $Script:Messages.AnalyzingBackups -Type Info
    
    # Backup-Informationen sammeln
    $validBackups = @()
    
    foreach ($directory in $backupDirectories) {
        $backupInfo = [GpoBackupInfo]::new($directory.Name, $directory.FullName)
        $backupXmlPath = Join-Path $directory.FullName $Script:Config.BackupXmlFileName
        
        if (Test-Path $backupXmlPath) {
            $metadata = Get-GpoBackupMetadata -BackupXmlPath $backupXmlPath
            
            if ($metadata.IsValid) {
                $backupInfo.DisplayName = $metadata.DisplayName
                $backupInfo.GpoId = if ($metadata.GpoId) { $metadata.GpoId } else { $directory.Name }
                
                # Backup-Zeit parsen
                if ($metadata.CreatedTime) {
                    try {
                        $backupInfo.BackupTime = [DateTime]::Parse($metadata.CreatedTime)
                    }
                    catch {
                        $backupInfo.BackupTime = $directory.LastWriteTime
                    }
                } else {
                    $backupInfo.BackupTime = $directory.LastWriteTime
                }
                
                $backupInfo.IsValid = $true
                $validBackups += $backupInfo
                
                Write-StatusMessage ($Script:Messages.BackupAnalysisSuccess -f $backupInfo.DisplayName) -Type Success
            } else {
                $backupInfo.ErrorMessage = $metadata.ErrorMessage
                Write-StatusMessage ($Script:Messages.BackupAnalysisWarning -f $directory.Name, "Metadaten konnten nicht gelesen werden") -Type Warning
            }
        } else {
            $backupInfo.ErrorMessage = "Backup.xml nicht gefunden"
            Write-StatusMessage ($Script:Messages.BackupAnalysisWarning -f $directory.Name, "Backup.xml nicht gefunden") -Type Warning
        }
    }
    
    if ($validBackups.Count -eq 0) {
        throw $Script:Messages.NoValidBackups
    }
    
    # Nach Backup-Zeit sortieren (neueste zuerst)
    return $validBackups | Sort-Object BackupTime -Descending
}

function Get-UserSelectedBackups {
    <#
    .SYNOPSIS
        Ermöglicht die interaktive Auswahl von GPO-Backups durch den Benutzer.
    #>
    param(
        [Parameter(Mandatory)]
        [GpoBackupInfo[]]$AvailableBackups
    )
    
    Write-GpoBackupList -BackupList $AvailableBackups
    
    do {
        $userInput = Read-Host "Nummer(n) der zu importierenden GPOs (kommasepariert, z.B. 1,3,5)"
        $selectedNumbers = $userInput.Split(',') | ForEach-Object { 
            $trimmed = $_.Trim()
            [int]$number = 0
            if ([int]::TryParse($trimmed, [ref]$number)) {
                $number
            }
        }
        
        $isValidSelection = $selectedNumbers | ForEach-Object {
            $_ -ge 1 -and $_ -le $AvailableBackups.Count
        }
        
        if ($isValidSelection -contains $false) {
            Write-StatusMessage "Ungültige Auswahl. Bitte wählen Sie Nummern zwischen 1 und $($AvailableBackups.Count)." -Type Warning
            $validInput = $false
        } else {
            $validInput = $true
        }
    } while (-not $validInput)
    
    # Ausgewählte Backups zurückgeben
    $selectedBackups = $selectedNumbers | ForEach-Object { $AvailableBackups[$_ - 1] }
    
    # Auswahl bestätigen
    Write-GpoBackupList -BackupList $selectedBackups -Title "Ausgewählte GPOs für Import"
    
    $confirmation = Read-Host "`nImport starten? (J/N)"
    if ($confirmation -notmatch $Script:Config.ConfirmationPattern) {
        Write-StatusMessage $Script:Messages.UserCancelled -Type Warning
        return $null
    }
    
    return $selectedBackups
}

function Get-BackupsByNames {
    <#
    .SYNOPSIS
        Sucht GPO-Backups anhand ihrer Namen.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GpoNameList,
        
        [Parameter(Mandatory)]
        [GpoBackupInfo[]]$AvailableBackups
    )
    
    $requestedNames = $GpoNameList.Split(',') | ForEach-Object { $_.Trim() }
    $foundBackups = @()
    $notFoundNames = @()
    
    foreach ($name in $requestedNames) {
        $matchingBackup = $AvailableBackups | Where-Object { $_.DisplayName -eq $name -and $_.IsValid }
        if ($matchingBackup) {
            $foundBackups += $matchingBackup
        } else {
            $notFoundNames += $name
        }
    }
    
    # Fehlende GPO-Backups melden
    if ($notFoundNames.Count -gt 0) {
        foreach ($name in $notFoundNames) {
            Write-StatusMessage "GPO-Backup nicht gefunden: $name" -Type Warning
        }
    }
    
    if ($foundBackups.Count -eq 0) {
        throw "Keine der angegebenen GPO-Backups wurde gefunden."
    }
    
    return $foundBackups
}

function Initialize-GroupPolicyModule {
    <#
    .SYNOPSIS
        Lädt und initialisiert das GroupPolicy-Modul.
    #>
    try {
        Import-Module GroupPolicy -ErrorAction Stop
        return $true
    }
    catch {
        throw "GroupPolicy-Modul konnte nicht geladen werden: $($_.Exception.Message)"
    }
}

function Import-GpoBackups {
    <#
    .SYNOPSIS
        Führt den eigentlichen Import der ausgewählten GPO-Backups durch.
    #>
    param(
        [Parameter(Mandatory)]
        [GpoBackupInfo[]]$BackupsToImport,
        
        [Parameter(Mandatory)]
        [string]$SourcePath,
        
        [Parameter(Mandatory)]
        [string]$Domain
    )
    
    Write-StatusMessage $Script:Messages.ImportStarting -Type Info
    
    $timestamp = Get-Date -Format $Script:Config.DateTimeFormat
    $logFilePath = Join-Path $SourcePath $Script:Config.LogFileName
    $logEntries = @()
    $successCount = 0
    $errorCount = 0
    
    foreach ($backup in $BackupsToImport) {
        Write-StatusMessage ($Script:Messages.ImportingGpo -f $backup.DisplayName) -Type Info
        
        $attemptCount = 0
        $importSuccessful = $false
        $lastError = $null
        
        # Retry-Logik für robusteren Import
        while ($attemptCount -lt $Script:Config.MaxRetryAttempts -and -not $importSuccessful) {
            $attemptCount++
            
            try {
                # GPO importieren mit CreateIfNeeded-Parameter
                Import-GPO `
                    -BackupId $backup.BackupId `
                    -TargetName $backup.DisplayName `
                    -Path $SourcePath `
                    -Domain $Domain `
                    -CreateIfNeeded `
                    -ErrorAction Stop
                
                # Erfolgreichen Import protokollieren
                $logEntry = "$timestamp - ERFOLG - Name: $($backup.DisplayName) - BackupId: $($backup.BackupId) - Domain: $Domain"
                if ($attemptCount -gt 1) {
                    $logEntry += " (Versuch $attemptCount)"
                }
                $logEntries += $logEntry
                
                Write-StatusMessage $Script:Messages.ImportSuccess -Type Success
                $successCount++
                $importSuccessful = $true
            }
            catch {
                $lastError = $_.Exception.Message
                
                if ($attemptCount -lt $Script:Config.MaxRetryAttempts) {
                    Write-StatusMessage "  ⚠ Versuch $attemptCount fehlgeschlagen, wiederhole..." -Type Warning
                    Start-Sleep -Seconds 2
                }
            }
        }
        
        # Wenn alle Versuche fehlgeschlagen sind
        if (-not $importSuccessful) {
            $logEntry = "$timestamp - FEHLER - Name: $($backup.DisplayName) - BackupId: $($backup.BackupId) - Domain: $Domain - Fehler: $lastError"
            $logEntries += $logEntry
            
            Write-StatusMessage ($Script:Messages.ImportError -f $lastError) -Type Error
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
            $logFilePath = $null
        }
    }
    
    return @{
        SuccessCount = $successCount
        ErrorCount = $errorCount
        LogFilePath = $logFilePath
    }
}
#endregion

#region Hauptprogramm
function Start-GpoImportProcess {
    <#
    .SYNOPSIS
        Hauptfunktion zur Koordination des Import-Prozesses.
    #>
    try {
        Write-ToolHeader
        
        # Parametervalidierung
        if (-not $ImportPath -and $GpoNames) {
            Write-StatusMessage "FEHLER: Wenn GPO-Namen angegeben werden, muss auch der Import-Pfad angegeben werden!" -Type Error
            Write-StatusMessage "`nVerwendung:" -Type Info
            Write-StatusMessage "  Komplett interaktiv:  .\GPO-Import-Optimized.ps1" -Type Info
            Write-StatusMessage "  Mit Pfad:             .\GPO-Import-Optimized.ps1 -ImportPath `"C:\GPO-Backups`"" -Type Info
            Write-StatusMessage "  Mit Parametern:       .\GPO-Import-Optimized.ps1 -ImportPath `"C:\GPO-Backups`" -GpoNames `"Name1,Name2`"" -Type Info
            exit 1
        }
        
        # GroupPolicy-Modul laden
        Initialize-GroupPolicyModule | Out-Null
        
        # Import-Pfad bestimmen
        if (-not $ImportPath) {
            $ImportPath = Get-ImportPathFromUser
        }
        
        # Verfügbare Backups analysieren
        $availableBackups = Get-GpoBackupDirectories -SearchPath $ImportPath
        
        # GPO-Backups für Import auswählen
        if ($GpoNames) {
            # Parameter-Modus: Backups nach Namen suchen
            $selectedBackups = Get-BackupsByNames -GpoNameList $GpoNames -AvailableBackups $availableBackups
        } else {
            # Interaktiver Modus: Benutzerauswahl
            $selectedBackups = Get-UserSelectedBackups -AvailableBackups $availableBackups
            if ($null -eq $selectedBackups) {
                exit 0
            }
        }
        
        # Import durchführen
        $importResult = Import-GpoBackups -BackupsToImport $selectedBackups -SourcePath $ImportPath -Domain $TargetDomain
        
        # Zusammenfassung anzeigen
        Write-ImportSummary -SuccessCount $importResult.SuccessCount -ErrorCount $importResult.ErrorCount -Domain $TargetDomain -LogFilePath $importResult.LogFilePath
        
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
Start-GpoImportProcess
#endregion
