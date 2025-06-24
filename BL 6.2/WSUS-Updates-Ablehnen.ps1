#Requires -Version 5.1
#Requires -RunAsAdministrator

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

function Format-TitleShort {
    param(
        [string]$title,
        [string[]]$kbArticles,
        [int]$maxLen = 70
    )

    # Titel als String sicherstellen
    $title = [string]$title

    # KB-Nummer extrahieren aus $kbArticles
    $kb = ""
    if ($kbArticles -and $kbArticles.Count -gt 0) {
        $kb = "KB" + $kbArticles[0]
    }

    # KB-Nummer (inkl. Klammern) aus dem Titel entfernen (alle Vorkommen)
    if ($kb) {
        # Entfernt alle Vorkommen von (KBxxxxxxx) oder KBxxxxxxx im Titel
        $title = $title -replace '\(?KB\d+\)?', ''
        $title = $title.Trim()
    }

    # Titel kürzen, falls zu lang
    if ($title.Length -gt $maxLen) {
        $title = $title.Substring(0, $maxLen).TrimEnd() + "..."
    }

    return @{ Title = $title; KB = $kb }
}

function Write-Color {
    param(
        [string]$text,
        [ConsoleColor]$color
    )
    $origColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $color
    Write-Host -NoNewline $text
    $Host.UI.RawUI.ForegroundColor = $origColor
}

# Finale Liste veralteter Microsoft-Produkte (bereinigt und sortiert)
$productsToDecline = @(
    # Windows Server-Produkte
    "Server 2003", "Windows Server 2008", "Windows Server 2012", "Windows Server 2019",
    "Windows Server 2022", "Windows Server 2025",
    "Small Business Server", "Small Business Server 2011", "Business Server 2015",
    "SharePoint Server", "SharePoint Server 2016", "SharePoint Server 2019",
    "System Center",
    "Windows Essential Business Server 2008", "Windows Essential Business Server 2008 Setup Updates",
    "Windows Essential Business Server Preinstallation Tools",
    "Windows Server Technical Preview Language Packs",
    "Windows Server Solutions Best Practices Analyzer 1.0", "Microsoft Monitoring Agent",
    
    # Exchange Server
    "Exchange Server 2000", "Exchange 2000 Server", "Exchange Server 2007",
    "Exchange Server 2010", "Exchange Server 2013", "Exchange Server 2016", "Exchange Server 2019",
    "Antigen for Exchange/SMTP",
    
    # SQL Server
    "SQL Server 2000", "SQL Server 2005", "SQL Server 2008", "SQL Server 2012", "SQL Server 2014",
    "SQL Server 2017", "Microsoft SQL Server 2019",
    "Microsoft SQL Server Management Studio v17",
    "SQL Server Feature Pack",
    
    # BizTalk Server
    "BizTalk Server 2002", "BizTalk Server 2006R2", "BizTalk Server 2009", "BizTalk Server 2013",
    
    # Host Integration Server
    "Host Integration Server 2000", "Host Integration Server 2004", "Host Integration Server 2006",
    "Host Integration Server 2009", "Host Integration Server 2010",
    
    # Kommunikations-Server
    "Microsoft Lync Server", "Microsoft Lync Server 2010", "Microsoft Lync 2010", "Microsoft Lync 2013",
    "Office Communicator Server", "Office Communicator Server 2007", "Office Communications Server",
    "Office Communications Server 2007", "Office Communicator 2007 R2", 
    "Skype for Business", "Skype for Business 2015",
    
    # Office-Produkte (einzelne Anwendungen)
    "Office XP", "Office 2003", "Office 2007", "Office 2010", "Office 2013", "Office 365",
    "Microsoft 365", "Office 2002/XP", "Office Live Add-in",
    
    # Publisher-Versionen
    "Publisher", "Publisher 2000", "Publisher 2002", "Publisher 2003", "Publisher 2007",
    "Publisher 2010", "Publisher 2013",
    
    # Visio-Versionen  
    "Visio", "Visio 2000", "Visio 2002", "Visio 2003", "Visio 2007", "Visio 2010", "Visio 2013",
    
    # Project-Versionen
    "Project", "Project 2000", "Project 2002", "Project 2003", "Project 2007", "Project 2010", "Project 2013",
    
    # Einzelne Office-Apps (alte Versionen)
    "Access", "Access 2002", "Outlook", "Outlook 2002", "Word", "Word 2002", "Excel", "Excel 2002",
    
    # Visual Studio
    "Visual Studio 2005", "Visual Studio 2008", "Visual Studio 2010", "Visual Studio 2012",
    "Visual Studio 2013", "Visual Studio 2015",
    
    # Windows-Betriebssysteme
    "Windows 2000", "Windows XP", "Windows Vista", "Windows 7", "Windows 8", "Windows 8.1", 
    "Windows RT", "Windows Embedded",
    
    # Browser und Web-Technologien
    "Internet Explorer", "Microsoft Edge Legacy", "Silverlight",
    "Bing Bar", "Search Enhancement Pack",
    
    # Sicherheits- und Management-Tools
    "Forefront Identity Manager", "Forefront Identity Manager 2010", "Forefront Identity Manager 2010 R2",
    "Forefront Client Security", "Forefront Endpoint Protection 2010",
    "Forefront Protection Category", "Forefront Server Security Category",
    "Forefront Threat Management Gateway, Definition Updates for HTTP Malware Inspection",
    "Forefront TMG", "Forefront TMG MBE", "Firewall Client for ISA Server",
    "Internet Security and Acceleration Server 2004", "Internet Security and Acceleration Server 2006",
    "Security Essentials", "OneCare Family Safety Installation",
    "Microsoft BitLocker Administration and Monitoring v1", "Microsoft Advanced Threat Analytics",
    
    # Virtualisierung
    "Virtual PC", "Virtual Server",
    "Microsoft Application Virtualization 4.5", "Microsoft Application Virtualization 4.6",
    "Microsoft Application Virtualization 5.0",
    
    # Expression-Suite (Webdesign-Tools)
    "Expression Design 1", "Expression Design 2", "Expression Design 3", "Expression Design 4",
    "Expression Media 2", "Expression Media V1", "Expression Web 3", "Expression Web 4",
    
    # Microsoft Works
    "Microsoft Works 8", "Microsoft Works 9", "Works 6-9 Converter",
    
    # Microsoft Dynamics CRM
    "Microsoft Dynamics CRM 2011", "Microsoft Dynamics CRM 2011 SHS", "Microsoft Dynamics CRM 2013", 
    "Microsoft Dynamics CRM 2015", "Microsoft Dynamics CRM 2016", "Microsoft Dynamics CRM 2016 SHS",
    
    # Windows Live
    "Windows Live", "Windows Live Toolbar",
    
    # Windows Azure Pack-Komponenten
    "Windows Azure Pack: Admin API", "Windows Azure Pack: Admin Authentication Site",
    "Windows Azure Pack: Admin Site", "Windows Azure Pack: Configuration Site",
    "Windows Azure Pack: Microsoft Best Practice Analyzer", "Windows Azure Pack: Monitoring Extension",
    "Windows Azure Pack: MySQL Extension", "Windows Azure Pack: PowerShell API",
    "Windows Azure Pack: SQL Server Extension", "Windows Azure Pack: Tenant API",
    "Windows Azure Pack: Tenant Authentication Site", "Windows Azure Pack: Tenant Public API",
    "Windows Azure Pack: Tenant Site", "Windows Azure Pack: Usage Extension",
    "Windows Azure Pack: Web App Gallery Extension", "Windows Azure Pack: Web Sites",
    "Microsoft Azure Site Recovery Provider"
    
    # Entwickler- und Reporting-Tools
    "ASP.NET Web Frameworks", "Report Viewer 2005", "Report Viewer 2008", "Report Viewer 2010",
    "Microsoft StreamInsight V1.0",
    
    # Monitoring- und Management-Tools
    "Data Protection Manager 2006", "HPC Pack 2008", "Network Monitor 3",
    "Service Bus for Windows Server 1.1",
    
    # Health- und Multimedia-Tools
    "HealthVault Connection Center", "HealthVault Connection Center Upgrades",
    "Microsoft Research AutoCollage 2008", "Photo Gallery Installation and Upgrades",
    
    # Windows-Extras und Spiele
    "DreamScene", "Pokerspiel", 'Pokerspiel "Hold Em"', "Tinker", "Windows Ultimate Extras",
    "Writer Installation and Upgrades",
    
    # Hardware-spezifische Treiber
    "Surface Hub 2S drivers",
    
    # Threat Management Gateway (weitere Komponenten)
    "Threat Management Gateway Definition Updates for Network Inspection System",
    "TMG Firewall Client",
    
    # Windows 10 S (Education-Edition, nicht für Business)
    "Windows 10 S and Later Servicing Drivers",
    "Windows 10 S Version 1709 and Later Servicing Drivers for testing",
    "Windows 10 S Version 1709 and Later Upgrade & Servicing Drivers for testing",
    "Windows 10 S Version 1803 and Later Servicing Drivers",
    "Windows 10 S Version 1803 and Later Upgrade & Servicing Drivers",
    "Windows 10 S, version 1809 and later, Servicing Drivers",
    "Windows 10 S, version 1809 and later, Upgrade & Servicing Drivers",
    "Windows 10 S, version 1903 and later, Servicing Drivers",
    "Windows 10 S, version 1903 and later, Upgrade & Servicing Drivers",
    "Windows 10 S, Vibranium and later, Servicing Drivers",
    "Windows 10 S, Vibranium and later, Upgrade & Servicing Drivers",
 
    
    # Weitere veraltete Sicherheitstools
    "Microsoft Online Services Sign-In Assistant",
    
    # Verschiedene Legacy-Tools
    "CAPICOM", "Compute Cluster Pack", "Device Health", 
    "Dictionary Updates for Microsoft IMEs", "New Dictionaries for Microsoft IMEs",
    "Windows Dictionary Updates","Windows Safe OS Dynamic Update", "Search Enhancement Pack"
)

# Verbindung zu WSUS (lokal, kein SSL, Port 8530)
[void][reflection.assembly]::LoadWithPartialName('Microsoft.UpdateServices.Administration')
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($env:COMPUTERNAME.$env:USERDNSDOMAIN" $true, 8531)

# Funktion: Bestimme den Grund für Ablehnung
function Get-DeclineReason {
    param($update)
    if ($update.IsBeta) { return "Beta" }
    if ($update.IsSuperseded) { return "Superseded" }
    foreach ($pt in $update.ProductTitles) {
        foreach ($prod in $productsToDecline) {
            if ($pt.IndexOf($prod, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                return $prod
            }
        }
    }
    return $null
}

# Updates laden
Write-Host "Updates werden geladen..."
$scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$scope.ExcludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotApplicable
$updates = $wsus.GetUpdates($scope) | Where-Object { -not $_.IsDeclined }
Write-Host "$($updates.Count) Updates gefunden.`n"

# Gruppierung vorbereiten: Dictionary mit Listen je Ablehnungsgrund
$groupedUpdates = @{}

foreach ($update in $updates) {
    $reason = Get-DeclineReason -update $update
    if ($reason) {
        if (-not $groupedUpdates.ContainsKey($reason)) {
            $groupedUpdates[$reason] = @()
        }
        $groupedUpdates[$reason] += $update
    }
}

# Gruppenweise Ablehnen und Ausgabe mit Farbe
$totalDeclined = 0
$totalFailed = 0

foreach ($group in $groupedUpdates.Keys) {
    Write-Host -ForegroundColor Cyan "`n=== $group ====================================================================================================="
    foreach ($update in $groupedUpdates[$group]) {
        try {
            $update.Decline()

            # Formatieren
            $formatResult = Format-TitleShort -title $update.Title -kbArticles $update.KnowledgebaseArticles
            $shortTitle = $formatResult.Title
            $kb = $formatResult.KB

            # Ausgabe
            Write-Host "[x] " -Foregroundcolor Red -NoNewline
            Write-Host "[$($group)]" -Foregroundcolor Cyan -NoNewline
            if ($kb) {
                Write-Host -NoNewline " $shortTitle "
                Write-Host "($kb)" -Foregroundcolor Yellow
            } else {
                Write-Host " $shortTitle "
            }
            $totalDeclined++
        }
        catch {
            Write-Host "  FEHLER bei '$($update.Title)'"
            $totalFailed++
        }
    }
    Write-Host ""
}


# Sprachen ablehnen
$languages = $updates | Where-Object {
    $_.ProductTitles -like "*Language*"
} | Where-Object {
    $_.Title -notmatch '\[en-US_LP\]' -and $_.Title -notmatch '\[de-DE_LP\]'
}

foreach ($language in $languages) {
    Write-Host -ForegroundColor Cyan "`n=== Sprachpakete ====================================================================================================="
    try {
        $language.Decline()

        # Formatieren
        $formatResult = Format-TitleShort -title $language.Title -kbArticles $language.KnowledgebaseArticles
        $shortTitle = $formatResult.Title
        $kb = $formatResult.KB

        # Ausgabe
        Write-Host "[x] " -Foregroundcolor Red -NoNewline
        Write-Host "[Sprachpaket]" -Foregroundcolor Cyan -NoNewline
        if ($kb) {
            Write-Host -NoNewline " $shortTitle "
            Write-Host "($kb)" -Foregroundcolor Yellow
        } else {
            Write-Host " $shortTitle "
        }
        $totalDeclined++
    }
    catch {
        Write-Host "  FEHLER bei '$($language.Title)'"
        $totalFailed++
    }
    Write-Host ""
}

# Abschluss
Write-Host "Fertig."
Write-Host "Abgelehnt: $totalDeclined"
if ($totalFailed -gt 0) {
    Write-Host "Fehler: $totalFailed"
}


# $updates.ProductTitles | Sort-Object -Unique
