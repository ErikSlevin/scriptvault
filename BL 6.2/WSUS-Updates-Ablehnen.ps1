<#
.SYNOPSIS
    WSUS Updates automatisch ablehnen basierend auf Produkte und Titel
.DESCRIPTION
    Dieses PowerShell-Script verbindet sich mit einem WSUS-Server und 
    lehnt automatisch Updates ab, die für veraltete oder unerwünschte Produkte 
    bestimmt sind. Das Script überprüft die ProductTitles der Updates sowie
    den Titel und lehnt Updates ab, die bestimmte Begriffe enthalten.
.PARAMETER WSUSServer
    Der FQDN oder die IP-Adresse des WSUS-Servers
    
.PARAMETER Port
    Der Port des WSUS-Servers (Standard: 8531)
    
.PARAMETER UseSSL
    Verwendet SSL für die Verbindung (Standard: $true)
    
.PARAMETER WhatIf
    Führt eine Simulation aus ohne tatsächliche Änderungen
    
.PARAMETER LogPath
    Pfad zur Logdatei (Standard: D:\WSUS\WSUS-Cleanup.log)
.NOTES
    Dateiname:    WSUS-Updates-Ablehnen.ps1
    Autor:        Erik Slevin
    Erstellt:     10.06.2025
    Version:      0.1
    Voraussetzung: WSUS-Server muss erreichbar und konfiguriert sein gem. InstAnw.
                    
.EXAMPLE
    .\WSUS-Updates-Ablehnen.ps1
    Führt das Script mit Standardparametern aus
    
.EXAMPLE
    .\WSUS-Updates-Ablehnen-Optimiert.ps1 -WSUSServer "wsus.domain.local" -WhatIf
    Simulation ohne tatsächliche Änderungen
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$WSUSServer = "$env:COMPUTERNAME.$env:USERDNSDOMAIN",
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 8531,
    
    [Parameter(Mandatory = $false)]
    [bool]$UseSSL = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "D:\WSUS\WSUS-Cleanup.log"
)
# Log-Verzeichnis erstellen falls nicht vorhanden
$logDirectory = Split-Path -Path $LogPath -Parent
if (-not (Test-Path -Path $logDirectory)) {
    try {
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        Write-Host "Log-Verzeichnis erstellt: $logDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler beim Erstellen des Log-Verzeichnisses: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Verwende aktuelles Verzeichnis für Logs" -ForegroundColor Yellow
        $LogPath = ".\WSUS-Cleanup.log"
    }
}
# Logging-Funktion
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Level zentriert auf 7 Zeichen
    $levelCentered = $Level.PadLeft([math]::Floor(($Level.Length + 7) / 2)).PadRight(7)
    $logEntry = "[$timestamp] [$levelCentered] $Message"
    
    # Farbkodierung für Konsole
    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # In Datei schreiben (wird automatisch ergänzt)
    try {
        Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    }
    catch {
        Write-Host "Warnung: Konnte nicht in Logdatei schreiben: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
# Konfiguration der abzulehnenden Produkte und Begriffe
$declineConfig = @{
    # Veraltete Produkte
    Products = @(
        # Windows Server Versionen (End-of-Life)
        "Server 2003",                    # Windows Server 2003 (EOL: 2015)
        "Windows Server 2008",            # Windows Server 2008/2008 R2 (EOL: 2020)
        "Windows Server 2012",            # Windows Server 2012/2012 R2 (EOL: 2023)
        "Windows Server 2019",            # Nicht verwendet
        "Windows Server 2022",            # Nicht verwendet
        "Windows Server 2025",            # Nicht verwendet
        
        # Exchange Server Versionen (veraltet)
        "Windows Exchange Server 2019",   # Ältere Exchange Version
        "Exchange Server 2013",           # Exchange 2013 (EOL: 2023)
        "Exchange Server 2016",           # Nicht verwendet
        "Exchange Server 2010",           # EOL
        "Exchange Server 2007",           # EOL
        "Exchange Server 2000",           # EOL
        "Microsoft Lync Server 2010",     # EOL
        "Microsoft Lync Server 2013",     # EOL

        # Sonstige Server-Produkte
        "Business Server 2015",           # Small Business Server (EOL)
        "SharePoint Server 2016",         # Nicht verwendet
        "SharePoint Server 2019",         # Nicht verwendet
        "System Center",                  # Nicht verwendet
        
        # SQL Server Versionen (veraltet)
        "SQL Server 2000",
        "SQL Server 2005",                # SQL Server 2008 (EOL: 2019)
        "SQL Server 2008",                # SQL Server 2008 (EOL: 2019)
        "SQL Server 2012",                # SQL Server 2012 (EOL: 2022)
        "SQL Server 2014",                # SQL Server 2014 (EOL: 2024)
        "SQL Server 2016",                # SQL Server 2016 (EOL: 2026) - prüfen ob verwendet
        "SQL Server 2017",                # Nicht verwendet
        "SQL Server 2019",                # Nicht verwendet
        
        # Office Versionen (End-of-Life) - Sie haben nur neuere
        "Office XP",                      # EOL
        "Office Communications Server 2007",
        "Office Communicator Server 2007 R2",
        "Office 2003",                    # Office 2003 (EOL: 2014)
        "Office 2007",                    # Office 2007 (EOL: 2017)
        "Office 2010",                    # Office 2010 (EOL: 2020)
        "Office 2013",                    # Office 2013 (EOL: 2023)
        "Microsoft Visio 2010",           # Visio 2010 (EOL: 2020)
        "Microsoft Visio 2013",           # Nicht verwendet
        "Microsoft Project 2010",         # Nicht verwendet
        "Microsoft Project 2013",         # Nicht verwendet
        "Microsoft Lync 2010",            # EOL
        "Visual Studio 2005",             # EOL
        "Visual Studio 2008",             # EOL
        "Visual Studio 2010",             # EOL
        "Visual Studio 2012",             # EOL
        
        # Windows Client Versionen (End-of-Life)
        "Windows 2000",                   # Windows 2000 (EOL: 2008)
        "Windows Vista",                  # Windows Vista (EOL: 2017)
        "Windows XP",                     # Windows XP (EOL: 2014)
        "Windows 7",                      # Windows 7 (EOL: 2020)
        "Windows 8",                      # Windows 8/8.1 (EOL: 2023)
        "Windows RT",                     # Windows RT (EOL)
        "Windows Embedded"                # Nicht verwendet
        "Forefront Identity Manager 2010 R2",
        "Forefront Identity Manager 2010",
        "Virtual PC",
        "Virtual Server"
    )
    
    # Unerwünschte Update-Muster im Titel
    TitlePatterns = @(
        # Sprachpakete (Language Packs) - außer Deutsch/Englisch
        "_LP",                            # Language Pack Suffix
        "_LIP",                           # Language Interface Pack Suffix
        "Language Interface Pack",        # Vollständige Sprachpakete
        "Language Pack",                  # Vollständige Sprachpakete
        
        # Entwickler-/Test-Versionen
        "Beta",                           # Beta-Versionen (Testversionen)
        "insider",                        # Windows Insider Preview Updates
        "Preview",                        # Vorschau-Versionen
        "Dev Kanal",                      # Development Channel Updates
        "Canary",                         # Canary Channel Updates
        "RC",                             # Release Candidate
        "CTP",                            # Community Technology Preview
        
        # Architektur-spezifische Ausschlüsse (falls nur 64-Bit)
        "Arm",                            # ARM-basierte Updates (falls keine ARM-Geräte)
        "ARM64",                          # ARM64 Updates
        "x86 Client",                     # 32-Bit Client Updates (falls nur 64-Bit)
        "x86-basierte",                   # Weitere 32-Bit Referenzen
        "Itanium",                        # Itanium-Architektur (veraltet)
        "IA64",                           # Intel Itanium 64-bit
        
        # PowerShell Versionen (falls nur Windows PowerShell gewünscht)
        "Powershell v7",                  # PowerShell Core v7
        "Powershell LTS v7",              # PowerShell LTS (Long Term Support) v7
        "PowerShell 7",                   # Alternative Schreibweise
        
        # Windows 11 Upgrade-Verhinderung
        "Upgrade to Windows 11",          # Windows 11 Upgrades
        
        # Superseded/Abgelöste Updates (werden automatisch erkannt, aber zusätzlich)
        "superseded",                     # Explizit abgelöste Updates
        "replaced",                       # Ersetzte Updates
        
        # Tools und Features die oft nicht benötigt werden
        "Windows Media Player",           # Falls nicht benötigt
        "Internet Explorer",              # Falls Edge verwendet wird
        "Microsoft Edge Legacy",          # Altes Edge (nicht Chromium)
        "Silverlight",                    # Veraltete Technologie
        
        # Server Core spezifisch (falls Sie GUI-Server haben)
        "Server Core",                    # Falls nur GUI-Server verwendet
        
        # Optionale Features die selten benötigt werden
        "Container",                      # Falls keine Container verwendet
        "WSL",                            # Windows Subsystem for Linux
        "Subsystem for Linux",            # Windows Subsystem for Linux
         
        "Pokerspiel",
        "Pokerspiel HoldEM",                     # 
        "Tinker",
        "SQL Server 2005",
        "SQL Server 2008",
        "Visio 2002",
        "PowerPoint 2002",
        "Office XP",
        "Project 2002", 
        "Visio 2002",
        "Access 2002",
        "Outlook 2002",
        "Exchange 2000",
        "Word 2002",
        "Publisher 2002",
        "Excel 2002",
        "Windows 8.1",
        "Taiwanese",
        "Japanisch",
        "DreamScene"              # 
    )
}

# Hauptfunktion
function Start-WSUSCleanup {
    Write-Log "======= WSUS Cleanup gestartet =======" "INFO"
    Write-Log "Script-Version: 2.1" "INFO"
    Write-Log "Server: $WSUSServer, Port: $Port, SSL: $UseSSL" "INFO"
    Write-Log "Logdatei: $LogPath" "INFO"
    
    try {
        # WSUS-Modul laden
        Write-Log "Lade WSUS-Modul..." "INFO"
        [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
        
        # Verbindung zum WSUS-Server herstellen
        Write-Log "Verbinde mit WSUS-Server..." "INFO"
        try {
            $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSServer, $UseSSL, $Port)
            Write-Log "Verbindung zum WSUS-Server erfolgreich hergestellt" "SUCCESS"
        }
        catch {
            Write-Log "Verbindung zum WSUS-Server fehlgeschlagen: $($_.Exception.Message)" "ERROR"
            throw
        }
        
        # Updates abrufen
        Write-Log "Lade Updates vom Server..." "INFO"
        $allUpdates = $wsus.GetUpdates()
        $pendingUpdates = $allUpdates | Where-Object { $_.IsDeclined -eq $false }
        
        Write-Log "Gefunden: $($allUpdates.Count) Updates gesamt, $($pendingUpdates.Count) noch nicht abgelehnt" "INFO"
        
        # Updates verarbeiten
        $declinedCount = 0
        $processedCount = 0
        
        foreach ($update in $pendingUpdates) {
            $processedCount++
            $shouldDecline = $false
            $declineReason = ""
            
            # Progress anzeigen
            if ($processedCount % 100 -eq 0) {
                Write-Progress -Activity "Updates verarbeiten" -Status "Update $processedCount von $($pendingUpdates.Count)" -PercentComplete (($processedCount / $pendingUpdates.Count) * 100)
            }
            
            # 1. Überprüfung: Abgelöste Updates
            if ($update.IsSuperseded) {
                $shouldDecline = $true
                $declineReason = "Veraltetes Update (Superseded)"
            }
            # 2. Überprüfung: Beta Updates
            elseif ($update.IsBeta) {
                $shouldDecline = $true
                $declineReason = "Beta Update"
            }
            # 3. Überprüfung: Produkt-Titel (nur wenn noch nicht zum Ablehnen markiert)
            elseif ($update.ProductTitles) {
                foreach ($productTitle in $update.ProductTitles) {
                    $matchedProduct = $declineConfig.Products | Where-Object { $productTitle -match [regex]::Escape($_) }
                    if ($matchedProduct) {
                        $shouldDecline = $true
                        $declineReason = "Veraltetes Produkt: $matchedProduct (in '$productTitle')"
                        break
                    }
                }
            }
            
            # 4. Überprüfung: Titel-Muster (nur wenn noch nicht zum Ablehnen markiert)
                if (-not $shouldDecline -and $update.Title) {
                    # Spezielle Behandlung für Language Packs (alle Arten)
                    if ($update.Title -match 'LanguageFeatureOnDemand' -or 
                        $update.Title -match 'Language Pack' -or 
                        $update.Title -match 'Language Interface Pack' -or
                        $update.Title -match '_LP' -or 
                        $update.Title -match '_LIP') {
                        # Überprüfen ob es sich um de-DE oder en-US handelt
                        if ($update.Title -notmatch '\[de-DE\]' -and $update.Title -notmatch '\[en-US\]') {
                            $shouldDecline = $true
                            $declineReason = "Language Pack: Unerwünschte Sprache (nur de-DE und en-US erlaubt)"
                        }
                    }
                    # Normale Titel-Muster Überprüfung (Language Pack Muster ausschließen, da bereits oben behandelt)
                    else {
                        foreach ($pattern in $declineConfig.TitlePatterns) {
                            # Language Pack Muster überspringen, da bereits oben behandelt
                            if ($pattern -in @('_LP', '_LIP', 'Language Interface Pack', 'Language Pack')) {
                                continue
                            }
                
                            if ($update.Title -match [regex]::Escape($pattern)) {
                                $shouldDecline = $true
                                $declineReason = "Unerwünschtes Muster: $pattern"
                                break
                            }
                        }
                    }
                }
            

            # Update ablehnen
            if ($shouldDecline) {
                if ($PSCmdlet.ShouldProcess($update.Title, "Update ablehnen")) {
                    try {
                        $update.Decline()
                        $declinedCount++
                        Write-Log "Abgelehnt: $($update.Title)" "SUCCESS"
                        Write-Log "    Grund: $declineReason" "INFO"
                    }
                    catch {
                        Write-Log "Fehler beim Ablehnen von '$($update.Title)': $($_.Exception.Message)" "ERROR"
                    }
                }
                else {
                    Write-Log "SIMULATION: Würde ablehnen - $($update.Title)" "WARNING"
                    Write-Log "  Grund: $declineReason" "INFO"
                    $declinedCount++
                }
            }
        }
        
        Write-Progress -Activity "Updates verarbeiten" -Completed
        Write-Log "Cleanup abgeschlossen" "SUCCESS"
        Write-Log "Verarbeitet: $processedCount Updates, Abgelehnt: $declinedCount Updates" "SUCCESS"
        Write-Log "======= WSUS Cleanup beendet =======" "INFO"
        Write-Log "" "INFO"  # Leerzeile für bessere Trennung zwischen Läufen
        
    }
    catch {
        Write-Log "Kritischer Fehler: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack Trace: $($_.Exception.StackTrace)" "ERROR"
        exit 1
    }
}
# Script ausführen
try {
    Start-WSUSCleanup
}
catch {
    Write-Log "Unerwarteter Fehler: $($_.Exception.Message)" "ERROR"
    exit 1
}
