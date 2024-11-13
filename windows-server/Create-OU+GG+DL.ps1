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

# Funktion zum Erstellen von Active Directory-GG-Gruppen
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

# Funktion zum Erstellen von Active Directory-DL-Gruppen
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
        [string]$GroupNames,  # Durch Komma getrennte Liste von Gruppennamen
        [boolean]$verbose = $false
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

                if ($verbose) {
                    # Wenn die Gruppe bereits existiert, wird eine Nachricht ausgegeben
                    Write-Host  -Foreground Red "$GroupName' existiert bereits."
                }
            }
        }
    }
}

# Funktionsaufruf zum erstellen von Freigaben
function New-Shares {
    <#
    .SYNOPSIS
    Erstellt Freigaben und zugehörige Gruppen für den Zugriff auf Ordner und gewährt Berechtigungen basierend auf den angegebenen Suffixen.
    
    .DESCRIPTION
    Diese Funktion erstellt für jede übergebene Freigabe in der Liste:
    - Den Ordner, falls er noch nicht existiert.
    - Eine Reihe von Domain-lokalen Active Directory-Gruppen mit den Suffixen "R", "RW", "RX", "FA".
    - Eine SMB-Freigabe für den Ordner, falls diese noch nicht existiert.
    - Setzt NTFS-Berechtigungen für die Ordner basierend auf den Suffixen der Gruppen.
    
    .PARAMETER freigaben
    Eine Liste von Hash-Tabellen, die die folgenden Eigenschaften für jede Freigabe enthalten:
    - Name: Der Name des Ordners
    - Freigabename: Der Name der SMB-Freigabe
    - Pfad: Der vollständige Pfad zum Ordner
    
    .EXAMPLE
    $freigaben = @(
        @{ Name = "Transfer_Chef"; Freigabename = "Transfer Chef"; Pfad = "C:\DFS\" },
        @{ Name = "Transfer_Abteilung_A; Freigabename = "Transfer Abteilung A"; Pfad = "C:\DFS\" }
    )
    New-Shares -freigaben $freigaben
    Dies erstellt für die Freigabe "Transfer_Chef" im Pfad "C:\DFS\":
    - Den Ordner, falls dieser noch nicht existiert.
    - Die Gruppen "DL_Transfer_Chef_R", "DL_Transfer_Chef_RW", "DL_Transfer_Chef_RX", "DL_Transfer_Chef_FA".
    - Eine SMB-Freigabe für den Ordner.
    - NTFS-Berechtigungen basierend auf den Gruppen.
    
    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell, SMB-Modul für PowerShell.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [Array]$freigaben  # Liste von Freigaben, die erstellt werden sollen
    )

    # Schleife über alle übergebenen Freigaben
    foreach ($freigabe in $freigaben) {
        # Pfad zum Ordner für die Freigabe erstellen
        $ordnerPfad = Join-Path -Path $freigabe.Pfad -ChildPath $freigabe.Name

        # Wenn der Ordner nicht existiert, erstelle ihn
        if (-not (Test-Path -Path $ordnerPfad)) {
            New-Item -Path $ordnerPfad -ItemType Directory -Force | Out-Null
            Write-Host -ForegroundColor Yellow "Erstelle Ordner: $ordnerPfad"
        }

        # Liste der Suffixe, die für die Gruppen benötigt werden
        $DL_Suffixe = @("R","RW","RX","FA")

        # Schleife über alle Suffixe, um Gruppen zu erstellen
        foreach ($Suffix in $DL_Suffixe) {
            # Erstelle den Gruppennamen basierend auf dem Freigabenamen und dem Suffix
            $Groupname = "DL_" + ($freigabe.Freigabename) + "_" + "$Suffix"
            
            # Überprüfe, ob die Gruppe bereits existiert
            $Groupexist = Get-ADGroup -Filter {Name -eq $Groupname} -ErrorAction SilentlyContinue

            # Falls die Gruppe nicht existiert, erstelle sie
            if (-not $Groupexist) {
                New-DL-Group -GroupNames $freigabe.Freigabename -verbose $false
            }
            
            # Speziell für das Suffix "FA" (Full Access) fügen wir den Administrator als Mitglied hinzu
            if ($Suffix -eq "FA") {
                (Get-ADGroup -Identity $Groupname).Name | Add-ADGroupMember -Members (Get-ADUser -Identity "Administrator")
            }
        }

        # Überprüfe, ob die SMB-Freigabe bereits existiert, wenn nicht, erstelle sie
        if (-not (Get-SmbShare -Name ($freigabe.Freigabename) -ErrorAction SilentlyContinue)) {
            Write-Host -ForegroundColor Yellow "Freigabe $($freigabe.Freigabename) existiert nicht - erstelle Freigabe"
            New-SmbShare -Name $freigabe.Freigabename -Path $freigabe.Pfad -FolderEnumerationMode AccessBased | Out-null
        }

        # Hole die SMB-Freigabe und gewähre "Authenticated Users" vollen Zugriff
        $Share = (Get-SmbShare -Name ($freigabe.Freigabename))
        Grant-SmbShareAccess $Share.Name -AccountName "Authenticated Users" -AccessRight Full -Force | Out-Null
        Revoke-SmbShareAccess $Share.Name -AccountName 'Everyone' -Force | Out-Null
        Write-Host -ForegroundColor Magenta  "`n"

        # Hole die aktuellen NTFS-Berechtigungen für den Ordner
        $acl = Get-Acl -Path $freigabe.Pfad
        $acl.SetAccessRuleProtection($true, $false)  # Setzt Schutz für die Berechtigungen (keine Vererbung)
        $acl | Set-Acl $freigabe.Path

        # Erstelle eine Liste von AccessRules basierend auf den Suffixen
        $AccessRules = @()

        foreach ($Suffix in $DL_Suffixe) {
            # Erstelle den Gruppennamen für jedes Suffix
            $Groupname = "DL_" + ($freigabe.Name) + "_" + "$Suffix"
            
            # Füge die entsprechenden Zugriffsregeln basierend auf dem Suffix hinzu
            switch ($Suffix) {
                "R" { 
                    $AccessRules += New-Object System.Security.AccessControl.FileSystemAccessRule("$Groupname","Read","Allow") 
                }
                "RW" { 
                    $AccessRules += New-Object System.Security.AccessControl.FileSystemAccessRule("$Groupname","Modify","Allow") 
                }
                "RX" { 
                    $AccessRules += New-Object System.Security.AccessControl.FileSystemAccessRule("$Groupname","ReadAndExecute","Allow") 
                }
                "FA" { 
                    $AccessRules += New-Object System.Security.AccessControl.FileSystemAccessRule("$Groupname","FullControl","Allow") 
                } 
            }

            # Setze die erstellten AccessRules für den Ordner
            foreach ($AccessRule in $AccessRules) {
                $acl.SetAccessRule($AccessRule)
            }

            # Wende die neuen NTFS-Berechtigungen an
            $acl | Set-Acl $freigabe.Pfad
        }
    }
}

# Funktionsaufruf zur Erstellung der OU-Struktur
Create-DomainOUStructure

# Funktionsaufruf zur Erstellung von GG-Gruppen 
New-GG-Group -GroupNames "Admin,Sales,HR"

# Funktionsaufruf zur Erstellung von DL-Gruppen 
New-DL-Group -GroupNames "Transfer_KpChef,Transfer_KpFw,Transfer_S2"

# Funktionsaufruf zur Erstellung von Freigaben
$freigaben = @(
    @{ Name = "Transfer_Chef"; Freigabename = "Transfer Chef"; Pfad = "C:\DFS\" },
    @{ Name = "Transfer_Abteilung_A; Freigabename = "Transfer Abteilung A"; Pfad = "C:\DFS\" }
)

New-Shares -freigaben $freigaben
