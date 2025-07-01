#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
WSUS-Management Hauptskript - All-in-One
    
.DESCRIPTION
Hauptskript für WSUS-Verwaltungsaufgaben mit integrierten Funktionen:
- Verbindung zum WSUS-Server
- Konsolen-Logging
- Datei-Logging

.NOTES
Version:        1.0.0
Autor:          Erik Slevin
Datum:          2025-07-01
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("LOCAL", "DOMAIN")]
    [string]$Mode = "LOCAL",
    
    [Parameter(Mandatory = $false)]
    [string]$ServerName,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableFileLogging
)

#region Integrierte Funktionen

function Write-WSUSLog {
    <#
    .SYNOPSIS
    Erstellt formatierte, farbige Log-Ausgaben mit Zeitstempel für WSUS-Operationen.
    
    .DESCRIPTION
    Erzeugt einheitliche Konsolen-Logs im Format: [HH:mm:ss] Nachricht
    Unterstützt verschiedene Status-Level mit automatischer Farbzuordnung.
    INLINE-Status geben nur Text ohne Zeitstempel aus.
    
    .PARAMETER Message
    Die auszugebende Nachricht.
    
    .PARAMETER Status
    Log-Level: INFO, SUBINFO, SUCCESS, WARNING, ERROR, DEBUG, INLINE_GREEN, INLINE_RED
    Standard: INFO
    
    .PARAMETER MessageColor
    Überschreibt die automatische Farbzuordnung.
    
    .PARAMETER NoNewLine
    Verhindert Zeilenumbruch nach der Ausgabe.
    
    .EXAMPLE
    Write-WSUSLog "WSUS-Server verbunden" -Status SUCCESS
    # [14:30:15] WSUS-Server verbunden (grün)
    
    .EXAMPLE
    Write-WSUSLog "Verarbeitung läuft..." -NoNewLine
    Write-WSUSLog " erfolgreich!" -Status INLINE_GREEN
    # [14:30:16] Verarbeitung läuft... erfolgreich!
    
    .EXAMPLE
    Write-WSUSLog "Detailinfo" -Status SUBINFO
    # [14:30:17] Detailinfo (dunkelgrau)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [ValidateSet("INFO", "SUBINFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "INLINE_GREEN", "INLINE_RED")]
        [string]$Status = "INFO",
        
        [ConsoleColor]$MessageColor,
        
        [switch]$NoNewLine
    )
    
    begin {
        # Farbzuordnung (einmalig definiert)
        $StatusColors = @{
            SUCCESS      = "Green"
            ERROR        = "Red"
            WARNING      = "Yellow"
            INFO         = "White"
            SUBINFO      = "DarkGray"
            DEBUG        = "Magenta"
            INLINE_GREEN = "Green"
            INLINE_RED   = "Red"
        }
        
        $InlineStatus = @("INLINE_GREEN", "INLINE_RED")
    }
    
    process {
        # Bei leerer Nachricht nur Leerzeile ausgeben
        if ([string]::IsNullOrEmpty($Message)) {
            Write-Host ""
            return
        }
        
        # Farbbestimmung
        $Color = if ($MessageColor) { $MessageColor } else { $StatusColors[$Status] }
        
        # INLINE-Status: Nur Text ohne Zeitstempel
        if ($Status -in $InlineStatus) {
            Write-Host $Message -NoNewline:$NoNewLine -ForegroundColor $Color
            return
        }
        
        # Standard-Ausgabe: [Zeitstempel] Nachricht
        $TimeStamp = Get-Date -Format "HH:mm:ss"
        
        Write-Host "[" -NoNewline -ForegroundColor White
        Write-Host $TimeStamp -NoNewline
        Write-Host "] " -NoNewline -ForegroundColor White
        Write-Host $Message -NoNewline:$NoNewLine -ForegroundColor $Color
    }
}

function Write-WSUSLogFile {
    <#
    .SYNOPSIS
    Schreibt Log-Einträge in eine tägliche WSUS-Logdatei unter D:\WSUS-DATEN\logfiles\.
    
    .DESCRIPTION
    Erstellt automatisch tägliche Logdateien im Format: YYYY-MM-DD-WSUS-Script.log
    Schreibt Einträge im Format: YYYY-MM-DD [TAB] HH:mm:ss [TAB] Logtext
    Erstellt bei Bedarf automatisch die benötigten Verzeichnisse.
    
    .PARAMETER Message
    Die zu protokollierende Nachricht.
    
    .PARAMETER LogPath
    Basis-Pfad für Logdateien. Standard: D:\WSUS-DATEN\logfiles\
    
    .PARAMETER FileName
    Optionaler Dateiname. Standard: YYYY-MM-DD-WSUS-Script.log
    
    .PARAMETER PassThru
    Gibt den vollständigen Pfad der Logdatei zurück (optional).
    
    .PARAMETER Append
    Fügt Eintrag zur bestehenden Datei hinzu (Standard). 
    $false überschreibt die Datei.
    
    .OUTPUTS
    Gibt den vollständigen Pfad der erstellten/verwendeten Logdatei zurück.
    
    .EXAMPLE
    Write-WSUSLogFile "WSUS-Server Verbindung hergestellt"
    # Schreibt in: D:\WSUS-DATEN\logfiles\2025-06-26-WSUS-Script.log
    # Inhalt: 2025-06-26	14:30:15	WSUS-Server Verbindung hergestellt
    
    .EXAMPLE
    Write-WSUSLogFile "Update-Synchronisation gestartet" -LogPath "C:\Logs\"
    # Verwendet alternativen Pfad
    
    .EXAMPLE
    $LogFile = Write-WSUSLogFile "Script gestartet" -PassThru
    Write-Host "Logdatei: $LogFile"
    # Gibt Pfad der Logdatei zurück (nur mit -PassThru Parameter)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = "D:\WSUS-DATEN\logfiles\",
        
        [Parameter(Mandatory = $false)]
        [string]$FileName,
        
        [Parameter(Mandatory = $false)]
        [bool]$Append = $true
    )
    
    begin {
        # Aktuelles Datum für Dateiname und Log-Eintrag
        $CurrentDate = Get-Date
        $DateString = $CurrentDate.ToString("yyyy-MM-dd")
        $TimeString = $CurrentDate.ToString("HH:mm:ss")
        
        # Dateiname bestimmen (falls nicht angegeben)
        if (-not $FileName) {
            $FileName = "$DateString-WSUS-Script.log"
        }
        
        # Vollständigen Pfad zusammensetzen
        $FullLogPath = Join-Path -Path $LogPath -ChildPath $FileName
        
        # Verzeichnis erstellen falls nicht vorhanden
        $LogDirectory = Split-Path -Path $FullLogPath -Parent
        if (-not (Test-Path -Path $LogDirectory)) {
            try {
                New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
                Write-WSUSLog "Log-Verzeichnis erstellt: $LogDirectory" -Status SUCCESS
            }
            catch {
                Write-WSUSLog "Fehler beim Erstellen des Log-Verzeichnisses: $($_.Exception.Message)" -Status ERROR
                throw
            }
        }
    }
    
    process {
        try {
            # Log-Eintrag im Format: YYYY-MM-DD [TAB] HH:mm:ss [TAB] Message
            $LogEntry = "$DateString`t$TimeString`t$Message"
            
            # In Datei schreiben
            if ($Append) {
                Add-Content -Path $FullLogPath -Value $LogEntry -Encoding UTF8
            } else {
                Set-Content -Path $FullLogPath -Value $LogEntry -Encoding UTF8
            }
            
            # Erfolg in Konsole ausgeben (nur bei Debugmodus)
            if ($PSBoundParameters.ContainsKey('Debug') -or $VerbosePreference -eq 'Continue') {
                Write-WSUSLog "Log geschrieben: $FileName" -Status DEBUG
            }
            
            # Nur bei expliziter Anfrage den Pfad zurückgeben
            if ($PSBoundParameters.ContainsKey('PassThru') -and $PassThru) {
                return $FullLogPath
            }
            
        }
        catch {
            Write-WSUSLog "Fehler beim Schreiben der Logdatei: $($_.Exception.Message)" -Status ERROR
            Write-WSUSLog "Pfad: $FullLogPath" -Status ERROR
            throw
        }
    }
}

function Connect-WSUSServer {
    <#
    .SYNOPSIS
    Stellt eine Verbindung zum WSUS-Server her - lokal oder domänenbasiert.
    
    .DESCRIPTION
    Verbindet sich mit dem WSUS-Server basierend auf der gewählten Konfiguration:
    - LOCAL: Lokaler Server ohne SSL (Port 8530)
    - DOMAIN: Domänen-Server mit SSL (Port 8531)
    
    .PARAMETER Mode
    Verbindungsmodus: LOCAL oder DOMAIN
    Standard: LOCAL
    
    .PARAMETER ServerName
    Optionaler Server-Name (überschreibt automatische Erkennung)
    
    .PARAMETER Port
    Optionaler Port (überschreibt Standard-Ports)
    
    .PARAMETER UseSSL
    Optionale SSL-Einstellung (überschreibt Standard-SSL-Konfiguration)
    
    .OUTPUTS
    Microsoft.UpdateServices.Administration.IUpdateServer
    WSUS-Server-Objekt bei erfolgreicher Verbindung
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode LOCAL
    # Verbindet zu lokalem WSUS ohne SSL auf Port 8530
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode DOMAIN
    # Verbindet zu Domänen-WSUS mit SSL auf Port 8531
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode DOMAIN -ServerName "wsus.firma.local"
    # Verbindet zu spezifischem Domänen-Server
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("LOCAL", "DOMAIN")]
        [string]$Mode = "LOCAL",
        
        [Parameter(Mandatory = $false)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [bool]$UseSSL
    )
    
    begin {
        # WSUS-Assembly laden
        try {
            Add-Type -Path "${env:ProgramFiles}\Update Services\Api\Microsoft.UpdateServices.Administration.dll" -ErrorAction Stop
        }
        catch {
            Write-WSUSLog "Fehler beim Laden der WSUS-Assembly: $($_.Exception.Message)" -Status ERROR
            throw "WSUS-Assembly konnte nicht geladen werden. Ist WSUS installiert?"
        }
    }
    
    process {
        try {
            # Konfiguration basierend auf Modus bestimmen
            switch ($Mode.ToUpper()) {
                "LOCAL" {
                    $ComputedServerName = if ($ServerName) { $ServerName } else { $env:COMPUTERNAME }
                    $ComputedUseSSL = if ($PSBoundParameters.ContainsKey('UseSSL')) { $UseSSL } else { $false }
                    $ComputedPort = if ($Port) { $Port } else { 8530 }
                }
                
                "DOMAIN" {
                    if ($ServerName) {
                        $ComputedServerName = $ServerName
                    } else {
                        if (-not $env:USERDNSDOMAIN) {
                            throw "Domäne konnte nicht ermittelt werden. Bitte ServerName-Parameter verwenden."
                        }
                        $ComputedServerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
                    }
                    
                    $ComputedUseSSL = if ($PSBoundParameters.ContainsKey('UseSSL')) { $UseSSL } else { $true }
                    $ComputedPort = if ($Port) { $Port } else { 8531 }
                }
            }
            
            
            $WSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer(
                $ComputedServerName,
                $ComputedUseSSL,
                $ComputedPort
            )        
            # Verbindungsdetails anzeigen
            Write-WSUSLog "WSUS-Verbindung erfolgreich hergestellt" -Status SUCCESS

            
            return $WSUSServer

        }
        catch {
            Write-WSUSLog "Fehler bei WSUS-Verbindung: $($_.Exception.Message)" -Status ERROR
            Write-WSUSLog "Server: $ComputedServerName | SSL: $ComputedUseSSL | Port: $ComputedPort"  -Status ERROR
        }
    }
}

#endregion

#region Script-Konfiguration
$script:StartTime = Get-Date
$script:WSUSServer = $null
#endregion

#region Hauptprogramm
try {
    # Begrüßung
    Clear-Host
    Write-Host -Foregroundcolor Green "`nWSUS Update Tool by Zwote 381"
    Write-Host -Foregroundcolor Green "-----------------------------"
    Write-Host -Foregroundcolor Green "Updates Verwaltung leicht gemacht`n"
    Write-WSUSLog "WSUS-Management Script gestartet" -Status SUCCESS
    Write-WSUSLog "Modus: $Mode" -Status SUBINFO
    
    # Optionales File-Logging
    if ($EnableFileLogging) {
        Write-WSUSLogFile "WSUS-Management Script gestartet - Modus: $Mode"
        Write-WSUSLog "Datei-Logging aktiviert" -Status SUCCESS
    }
    
    # WSUS-Server Verbindung herstellen
    Write-WSUSLog "Stelle Verbindung zum WSUS-Server her..." -Status SUBINFO
    
    $ConnectionParams = @{
        Mode = $Mode
    }
    
    if ($ServerName) {
        $ConnectionParams.ServerName = $ServerName
        Write-WSUSLog "Verwende benutzerdefinierten Server: $ServerName" -Status INFO
    }
    
    $script:WSUSServer = Connect-WSUSServer @ConnectionParams
    
    if ($null -eq $script:WSUSServer) {
        throw "WSUS-Server-Verbindung konnte nicht hergestellt werden"
    }
    
    # Server-Informationen anzeigen
    Write-WSUSLog "WSUS-Server Informationen:" -Status SUBINFO
    Write-WSUSLog "   - Name: $($script:WSUSServer.Name)" -Status SUBINFO
    Write-WSUSLog "   - Port: $($script:WSUSServer.PortNumber)" -Status SUBINFO
    Write-WSUSLog "   - SSL: $($script:WSUSServer.UseSecureConnection)" -Status SUBINFO
    Write-WSUSLog "   - Version: $($script:WSUSServer.Version)" -Status SUBINFO
    
    # Optional: Server-Info in Logdatei schreiben
    if ($EnableFileLogging) {
        Write-WSUSLogFile "WSUS-Server verbunden: $($script:WSUSServer.Name) | Port: $($script:WSUSServer.PortNumber) | SSL: $($script:WSUSServer.UseSecureConnection)"
    }
    
    # ========================================
    # HIER WEITERE FUNKTIONEN EINFÜGEN
    # ========================================
    
    Write-WSUSLog "Grundgerüst bereit für weitere Funktionen" -Status SUCCESS
    
}
catch {
    Write-WSUSLog "Kritischer Fehler: $($_.Exception.Message)" -Status ERROR
    
    if ($EnableFileLogging) {
        Write-WSUSLogFile "FEHLER: $($_.Exception.Message)"
    }
    
    # Fehlerdetails
    Write-WSUSLog "Stacktrace:" -Status ERROR
    Write-WSUSLog $_.ScriptStackTrace -Status ERROR
    
    exit 1
}
finally {
    # Aufräumarbeiten
    $EndTime = Get-Date
    $Duration = $EndTime - $script:StartTime
    
    Write-WSUSLog "Script beendet - Laufzeit: $($Duration.ToString('hh\:mm\:ss'))" -Status INFO
    
    if ($EnableFileLogging) {
        Write-WSUSLogFile "Script beendet - Laufzeit: $($Duration.ToString('hh\:mm\:ss'))"
    }
}
#endregion
