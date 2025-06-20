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
        #==============================#
        #       Windows Server         #
        #==============================#
        "Server 2003",                           		# EOL: Juli 2015
        "Windows Server 2008",                			# EOL: Jan 2020
        "Windows Server 2012",                			# EOL: Okt 2023
        # "Windows Server 2016",                		# verwendet
        "Windows Server 2019",                			# Nicht verwendet
        "Windows Server 2022",                			# Nicht verwendet
        "Windows Server 2025",                			# Nicht verwendet
    
        #==============================#
        #         Exchange Server      #
        #==============================#
        "Exchange Server 2000",               			# EOL: Juli 2011
        "Exchange Server 2007",               			# EOL: April 2017
        "Exchange Server 2010",               			# EOL: Okt 2020
        "Exchange Server 2013",               			# EOL: April 2023
        "Exchange Server 2016",               			# Nicht verwendet
        "Exchange Server 2019",               			# Nicht verwendet
    
        #==============================#
        #     Lync / Skype / OCS       #
        #==============================#
        "Microsoft Lync Server 2010",         			# EOL: ca. 2022
        "Microsoft Lync 2013",                			# EOL: ca. 2022
        "Microsoft Lync 2010",                			# EOL: ca. 2022
        "Office Communicator Server 2007",    			# EOL: ca. 2017
        "Office Communications Server 2007",  			# EOL: ca. 2017
        "Skype for Business 2015",           			# EOL: Okt 2025
    
        #==============================#
        #     SBS / SharePoint / SC     #
        #==============================#
        "Small Business Server 2011",         			# EOL: Jan 2020
        "Business Server 2015",              			# EOL: ca. 2020
        "SharePoint Server 2016",            			# Nicht verwendet
        "SharePoint Server 2019",            			# Nicht verwendet
        "System Center",                     			# Nicht verwendet
    
        #==============================#
        #         SQL Server           #
        #==============================#
        "SQL Server 2000",                   			# EOL: April 2013
        "SQL Server 2005",                   			# EOL: April 2016
        "SQL Server 2008",                   			# EOL: Juli 2019
        "SQL Server 2012",                   			# EOL: Juli 2022
        "SQL Server 2014",                   			# EOL: Juli 2024
        # "SQL Server 2016",                   			# verwendet
        "SQL Server 2017",                   			# Nicht verwendet
        "SQL Server 2019",                   			# Nicht verwendet
    
        #==============================#
        #       Office-Produkte        #
        #==============================#
        "Office XP",                            		# EOL: Juli 2011
        "Office 2003",                          		# EOL: April 2014
        "Office 2007",                          		# EOL: Okt 2017
        "Office 2010",                          		# EOL: Okt 2020
        "Office 2013",                          		# EOL: April 2023
        # "Office 2016",                          		# EOL: Okt 2025 (Mainstream Support Ende)
        # "Office 2019",                          		# EOL: Oktober 2025 (Langzeit)
        # "Office 2021",                          		# Aktuelle Version, LTS
        "Office 365",                          			# Nicht verwendet
        "Microsoft 365",                       			# Nicht verwendet

        #==============================#
        #      Publisher-Produkte      #
        #==============================#
        "Publisher 2000",                     			# EOL: ca. 2010
        "Publisher 2002",                     			# EOL: ca. 2007
        "Publisher 2003",                     			# EOL: April 2014
        "Publisher 2007",                     			# EOL: Okt 2017
        "Publisher 2010",                     			# EOL: Okt 2020
        "Publisher 2013",                     			# EOL: April 2023
        # "Publisher 2016",                    			# EOL: Okt 2025
        # "Publisher 2019",                  			# EOL: Okt 2025
        # "Publisher 2021",                     		# Aktuelle Version, LTS
        
        #==============================#
        #        Visio-Produkte        #
        #==============================#
        "Visio 2000",                        			# EOL: ca. 2010
        "Visio 2002",                        			# EOL: ca. 2007
        "Visio 2003",                        			# EOL: April 2014
        "Visio 2007",                        			# EOL: Okt 2017
        "Visio 2010",                       			# EOL: Okt 2020
        "Visio 2013",                       			# EOL: April 2023
        # "Visio 2016",                       			# EOL: Okt 2025
        # "Visio 2019",                        			# EOL: Okt 2025
        # "Visio 2021",                        			# Aktuelle Version, LTS
        
        #==============================#
        #         Project-Produkte     #
        #==============================#
        "Project 2000",                      			# EOL: ca. 2010
        "Project 2002",                      			# EOL: ca. 2007
        "Project 2003",                      			# EOL: April 2014
        "Project 2007",                      			# EOL: Okt 2017
        "Project 2010",                      			# EOL: Okt 2020
        "Project 2013",                      			# EOL: April 2023
        # "Project 2016",                      			# EOL: Okt 2025
        # "Project 2019",                      			# EOL: Okt 2025
        # "Project 2021",                      			# Aktuelle Version, LTS

        #==============================#
        #   Visio / Project / Einzel   #
        #==============================#
        "Project 2002",                      			# EOL: ca. 2007
        "Project 2010",                      			# Nicht verwendet
        "Project 2013",                      			# Nicht verwendet
        "Access 2002",                       			# EOL: ca. 2007
        "Outlook 2002",                      			# EOL: ca. 2007
        "Word 2002",                         			# EOL: ca. 2007
        "Excel 2002",                        			# EOL: ca. 2007
    
        #==============================#
        #        Visual Studio         #
        #==============================#
        "Visual Studio 2005",                			# EOL: ca. 2016
        "Visual Studio 2008",                			# EOL: April 2018
        "Visual Studio 2010",                			# EOL: Juli 2020
        "Visual Studio 2012",                			# EOL: Jan 2023
        "Visual Studio 2013",                			# EOL: April 2024 (geschätzt)
        "Visual Studio 2015",                			# EOL: Okt 2025 (geschätzt)
        # "Visual Studio 2017",                			# EOL: Okt 2025 (geschätzt)
        # "Visual Studio 2019",                			# EOL: Okt 2025 (geschätzt)
        # "Visual Studio 2022",                			# Aktuelle Version, Langzeit-Support
    
        #==============================#
        #          Windows OS          #
        #==============================#
        "Windows 2000",                      			# EOL: Juli 2010
        "Windows XP",                        			# EOL: April 2014
        "Windows Vista",                     			# EOL: April 2017
        "Windows 7",                         			# EOL: Jan 2020
        "Windows 8",                         			# EOL: Jan 2023
        "Windows 8.1",                       			# EOL: Jan 2023
        "Windows RT",                        			# EOL: ca. 2017
        "Windows Embedded",                  			# Nicht verwendet
    
        #==============================#
        #        Forefront / VM        #
        #==============================#
        "Forefront Identity Manager 2010",   			# EOL: ca. 2022
        "Forefront Identity Manager 2010 R2",			# EOL: ca. 2022
        "Virtual PC",                        			# EOL: ca. 2011
        "Virtual Server",                    			# EOL: ca. 2011
    
        #==============================#
        #      Browser / Add-ons       #
        #==============================#
        "Microsoft Edge Legacy",             			# EOL: März 2021
        "Internet Explorer",                 			# EOL: Juni 2022
        "Silverlight",                       			# EOL: Okt 2021
        "Windows Media Player",              			# Optional / selten benötigt
    
        #==============================#
        #   Sonstige / Demo-Spiele     #
        #==============================#
        "DreamScene",                        		    # Vista-Feature – EOL
        "Pokerspiel",                        		    # Demo-Spiel – abgewählt
        'Pokerspiel "Hold Em"',             			# Demo-Spiel – abgewählt
        "Tinker"                            		    # Demo-Spiel – abgewählt
    )

    
    # Unerwünschte Update-Muster im Titel
    TitlePatterns = @(
        # Sprachpakete (Language Packs) - außer Deutsch/Englisch
        "_LP",                            				# Language Pack Suffix
        "_LIP",                           				# Language Interface Pack Suffix
        "Language Interface Pack",        				# Vollständige Sprachpakete
        "Language Pack",                  				# Vollständige Sprachpakete

        # Architektur-spezifische Ausschlüsse (wenn keine Geräte mit dieser Architektur)
        "Arm",                           				# ARM-basierte Updates
        "ARM64",                         				# ARM64 Updates
        "IA64",                          				# Intel Itanium 64-bit
        "Itanium",                      				# Itanium-Architektur (veraltet)
        "x86 Client",                   				# 32-Bit Client Updates (bei nur 64-Bit Systemen)
        "x86-basierte",                 				# Weitere 32-Bit Referenzen

        # Entwickler-/Test-Versionen (Beta, Insider, Preview, Dev-Channel etc.)
        "Beta",                          				# Beta-Versionen (Testversionen)
        "Canary",                        				# Canary Channel Updates
        "CTP",                           				# Community Technology Preview
        "Dev Kanal",                     				# Development Channel Updates
        "Insider",                       				# Windows Insider Preview Updates
        "Preview",                       				# Vorschau-Versionen
        "RC",                           				# Release Candidate

        # PowerShell Versionen
        "PowerShell 7",                  				# PowerShell 7 (Core)
        "Powershell LTS v7",             				# PowerShell LTS (Long Term Support) v7
        "Powershell v7",                 				# PowerShell Core v7

        # Windows 11 Upgrade-Verhinderung
        "Upgrade to Windows 11",         				# Windows 11 Upgrade Updates

        # Superseded/Abgelöste Updates (werden meist automatisch erkannt)
        "replaced",                      				# Ersetzte Updates
        "superseded",                    				# Explizit abgelöste Updates

        # Tools und Features, die oft nicht benötigt werden
        "DreamScene",                    				# Vista Ultimate Feature – EOL
        "Internet Explorer",             				# Veralteter Browser – EOL
        "Microsoft Edge Legacy",         				# Altes Edge (nicht Chromium)
        "Pokerspiel",                   				# Demo-Spiel – abgewählt
        'Pokerspiel "Hold Em"',         				# Demo-Spiel – abgewählt
        "Silverlight",                  				# Veraltete Multimedia-Technologie
        "Tinker",                       				# Demo-Spiel – abgewählt

        # Server Core spezifisch (wenn nur GUI-Server verwendet werden)
        "Server Core",                   				# Server Core spezifische Updates

        # Optionale Features, die selten benötigt werden
        "Container",                    				# Container-Funktionalität (Docker, etc.)
        "Subsystem for Linux",           				# Windows Subsystem for Linux (WSL)
        "WSL",                           				# Abkürzung für Windows Subsystem for Linux

        # Veraltete Produkte/Versionen (teilweise mehrfach gelistet, alphabetisch sortiert)
        "Access 2002",                  				# Access 2002 (EOL ca. 2007)
        "Excel 2002",                  				    # Excel 2002 (EOL ca. 2007)
        "Exchange 2000",                				# Exchange 2000 (EOL Juli 2011)
        "Office XP",                   				    # Office XP (EOL Juli 2011)
        "PowerPoint 2002",              				# PowerPoint 2002 (EOL ca. 2007)
        "Project 2002",                				    # Project 2002 (EOL ca. 2007)
        "Publisher 2002",              				    # Publisher 2002 (EOL ca. 2007)
        "Visio 2002",                  				    # Visio 2002 (EOL ca. 2007)
        "Word 2002",                   				    # Word 2002 (EOL ca. 2007)

        # Sprachspezifische (nicht benötigte) Sprachpakete
        "Japanisch",                    				# Japanische Sprachpakete
        "Koreanisch",                  				    # Koreanische Sprachpakete
        "Taiwanese"                    				    # Taiwanesische Sprachpakete
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
