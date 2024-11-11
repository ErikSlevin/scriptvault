# Ermittle Distinguished Name 
function Get-DomainDN {
    <#
    .SYNOPSIS
    Holt den Distinguished Name (DN) der aktuellen Domain.
    
    .DESCRIPTION
    Diese Funktion ermittelt den Distinguished Name (DN) der aktuellen Domain und fragt den Benutzer 
    nach Bestätigung, dass der ermittelte Domain-Name korrekt ist.

    .EXAMPLE
    $DomainDN = Get-DomainDN
    Gibt den Distinguished Name der aktuellen Domain zurück.
    
    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell
    #>

    # Holt den FQDN (Fully Qualified Domain Name) der lokalen Maschine
    $DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    
    # Gibt den Distinguished Name (DN) der Domain zurück
    return (Get-ADDomain).DistinguishedName
}

# Funktion zum Erstellen der OU-Struktur
function Create-DomainOUStructure {
    <#
    .SYNOPSIS
    Erstellt eine vorgegebene OU-Struktur in der aktuellen Domain.

    .DESCRIPTION
    Diese Funktion erstellt die folgende OU-Struktur in der aktuellen Domain:
    
    - <DomainName>
        - Benutzer
            - Administratoren
            - Benutzer
            - Dienste
        - Gruppen
            - GG_Gruppen
            - DL_Gruppen
        - Server
        - Computer
    
    Der Distinguished Name der Domain wird automatisch ermittelt.

    .EXAMPLE
    Create-DomainOUStructure
    Erstellt die OU-Struktur in der aktuellen Domain.
    
    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell
    #>

    # Holt den Distinguished Name der Domain
    $DomainDN = Get-DomainDN

    # Extrahiert den Domainnamen aus dem Distinguished Name
    $RootOUName = ((Get-DomainDN) -split ',')[0] -replace 'DC=', ''

    # Erstellen der Wurzel-OU mit dem extrahierten Domainnamen
    New-ADOrganizationalUnit -Name $RootOUName -Path $DomainDN

    # Erstellen der Unter-OUs für "Benutzer"
    New-ADOrganizationalUnit -Name 'Benutzer' -Path "OU=$RootOUName,$DomainDN"
    New-ADOrganizationalUnit -Name 'Administratoren' -Path "OU=Benutzer,OU=$RootOUName,$DomainDN"
    New-ADOrganizationalUnit -Name 'Benutzer' -Path "OU=Benutzer,OU=$RootOUName,$DomainDN"
    New-ADOrganizationalUnit -Name 'Dienste' -Path "OU=Benutzer,OU=$RootOUName,$DomainDN"


    # Erstellen der Unter-OUs für "Gruppen"
    New-ADOrganizationalUnit -Name 'Gruppen' -Path "OU=$RootOUName,$DomainDN"
    New-ADOrganizationalUnit -Name 'GG_Gruppen' -Path "OU=Gruppen,OU=$RootOUName,$DomainDN"
    New-ADOrganizationalUnit -Name 'DL_Gruppen' -Path "OU=Gruppen,OU=$RootOUName,$DomainDN"

    # Erstellen der OU "Server"
    New-ADOrganizationalUnit -Name 'Server' -Path "OU=$RootOUName,$DomainDN"

    # Erstellen der OU "Computer"
    New-ADOrganizationalUnit -Name 'Computer' -Path "OU=$RootOUName,$DomainDN"


    Write-Host -ForegroundColor Green "$RootOUName"
    Write-Host -ForegroundColor Green " ├── Benutzer"
    Write-Host -ForegroundColor Green " │   ├── Administratoren"
    Write-Host -ForegroundColor Green " │   ├── Benutzer"
    Write-Host -ForegroundColor Green " │   └── Dienste"
    Write-Host -ForegroundColor Green " ├── Gruppen"
    Write-Host -ForegroundColor Green " │   ├── DL_Gruppen"
    Write-Host -ForegroundColor Green " │   └── GG_Gruppen"
    Write-Host -ForegroundColor Green " ├── Server"
    Write-Host -ForegroundColor Green " └── Computer"
}

# Funktion zum Erstellen von Active Directory-Gruppen
function New-GG-Group {
    <#
    .SYNOPSIS
    Erstellt Active Directory-Gruppen mit dem Präfix "GG_" in der OU "Gruppen -> GG-Gruppen".
    
    .DESCRIPTION
    Diese Funktion erstellt mehrere Gruppen in der OU "Gruppen -> GG-Gruppen" innerhalb der aktuellen Domain. 
    Der Gruppenname wird um das Präfix "GG_" ergänzt.
    
    .PARAMETER GroupNames
    Eine durch Kommata getrennte Liste von Gruppennamen (ohne Präfix), die erstellt werden sollen.
    
    .EXAMPLE
    New-GG_Group -GroupNames "Admin,Sales,HR"
    Erstellt die Gruppen "GG_Admin", "GG_Sales" und "GG_HR" in der OU "Gruppen -> GG-Gruppen".
    
    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell
    #>

    param (
        [string]$GroupNames  # Durch Komma getrennte Liste von Gruppennamen
    )
    
    # Durch die Gruppenliste iterieren
    $GroupNames.Split(',') | ForEach-Object {
        $GroupName = "GG_" + $_.Trim()  # Präfix "GG_" an den Gruppennamen anhängen
        $first_OU="OU=$((((Get-DomainDN) -split ',')[0] -replace 'DC=', ''))"
        $GroupPath = "OU=GG_Gruppen,OU=Gruppen,$($first_OU),$(Get-DomainDN)"  # Pfad zur OU "Gruppen"
        
        # Prüft, ob die Gruppe bereits existiert
        if (-not (Get-ADGroup -Filter { Name -eq $GroupName } -SearchBase $GroupPath -ErrorAction SilentlyContinue)) {
            # Wenn die Gruppe nicht existiert, wird sie erstellt
            New-ADGroup -Name $GroupName -Path $GroupPath -GroupScope Global -GroupCategory Security
            Write-Host -ForegroundColor Green "Gruppe '$GroupName' erstellt."
        } else {
            # Wenn die Gruppe bereits existiert, wird eine Nachricht ausgegeben
            Write-Host  -ForegroundColor Red "'$GroupName' existiert bereits."
        }
    }
}

function New-DL-Group {
    <#
    .SYNOPSIS
    Erstellt Domain-lokale Active Directory-Gruppen mit den Präfixen "DL_Gruppenname_R", "DL_Gruppenname_RW", "DL_Gruppenname_RX" und "DL_Gruppenname_FA" in der OU "DL-Gruppen".
    
    .DESCRIPTION
    Diese Funktion erstellt für jede übergebene Gruppe in der OU "DL-Gruppen" vier Domain-lokale Gruppen:
    - DL_Gruppenname_R
    - DL_Gruppenname_RW
    - DL_Gruppenname_RX
    - DL_Gruppenname_FA
    
    Der Gruppenname wird jeweils mit dem Präfix "DL_" ergänzt und eine passende Beschreibung wird für jede Gruppe gesetzt:
    - DL_Gruppenname_R: LESEN auf Gruppenname
    - DL_Gruppenname_RW: LESEN und SCHREIBEN auf Gruppenname
    - DL_Gruppenname_RX: LESEN und SCHREIBEN und AUSFÜHREN auf Gruppenname
    - DL_Gruppenname_FA: VOLLZUGRIFF auf Gruppenname
    
    .PARAMETER GroupNames
    Eine durch Kommata getrennte Liste von Gruppennamen (ohne Präfix), für die die Domain-lokalen Gruppen erstellt werden sollen.
    
    .EXAMPLE
    New-DL_Group -GroupNames "Admin,Sales,HR"
    Erstellt die Gruppen:
    - DL_Admin_R, DL_Admin_RW, DL_Admin_RX, DL_Admin_FA
    - DL_Sales_R, DL_Sales_RW, DL_Sales_RX, DL_Sales_FA
    - DL_HR_R, DL_HR_RW, DL_HR_RX, DL_HR_FA
    
    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell
    #>

    param (
        [string]$GroupNames  # Durch Komma getrennte Liste von Gruppennamen
    )
    
    # Durch die Gruppenliste iterieren
    $GroupNames.Split(',') | ForEach-Object {
        $BaseGroupName = $_.Trim()  # Entfernt Leerzeichen
        $first_OU="OU=$((((Get-DomainDN) -split ',')[0] -replace 'DC=', ''))"
        $GroupPath = "OU=DL_Gruppen,OU=Gruppen,$($first_OU),$(Get-DomainDN)"  # Pfad zur OU "Gruppen"
        
        # Erstellen der 4 Domain-lokalen Gruppen und Zuordnen der Beschreibungen
        $GroupVariants = @(
            @{ Name = "DL_${BaseGroupName}_R"; Description = "$($BaseGroupName): Lesen" },
            @{ Name = "DL_${BaseGroupName}_RW"; Description = "$($BaseGroupName): Lesen und Schreiben" },
            @{ Name = "DL_${BaseGroupName}_RX"; Description = "$($BaseGroupName): Lesen, Schreiben und Ausführen" },
            @{ Name = "DL_${BaseGroupName}_FA"; Description = "$($BaseGroupName): Vollzugriff" }
        )
        
        foreach ($GroupVariant in $GroupVariants) {
            $GroupName = $GroupVariant.Name
            $GroupDescription = $GroupVariant.Description

            # Prüft, ob die Gruppe bereits existiert
            if (-not (Get-ADGroup -Filter { Name -eq $GroupName } -SearchBase $GroupPath -ErrorAction SilentlyContinue)) {
                # Wenn die Gruppe nicht existiert, wird sie erstellt
                New-ADGroup -Name $GroupName -Path $GroupPath -GroupScope DomainLocal -GroupCategory Security
                Write-Host -Foreground Green "$GroupName' erstellt."
                
                # Setzt die Beschreibung der Gruppe
                Set-ADGroup -Identity $GroupName -Description $GroupDescription
            } else {
                # Wenn die Gruppe bereits existiert, wird eine Nachricht ausgegeben
                Write-Host  -Foreground Red "$GroupName' existiert bereits."
            }
        }
    }
}

# Funktionsaufruf zur Erstellung der OU-Struktur
Create-DomainOUStructure

# GG-Gruppen erstellen
New-GG-Group -GroupNames "Admin,Sales,HR"

# GG-Gruppen erstellen
New-DL-Group -GroupNames "Transfer_KpChef,Transfer_KpFw,Transfer_S2"
