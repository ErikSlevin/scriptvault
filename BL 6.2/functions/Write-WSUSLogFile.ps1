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
