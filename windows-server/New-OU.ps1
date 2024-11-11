# Funktion zum Erstellen von OUs (Organisatorischen Einheiten)
function New-OU {
    <#
    .SYNOPSIS
    Erstellt eine Organisationseinheit (OU) in Active Directory.
    
    .DESCRIPTION
    Diese Funktion erstellt eine OU im angegebenen übergeordneten Distinguished Name (DN). 
    Vor der Erstellung wird geprüft, ob die OU bereits existiert.

    .PARAMETER OUName
    Der Name der zu erstellenden OU.
    
    .PARAMETER ParentOU
    Der Distinguished Name der übergeordneten OU, unter der die neue OU erstellt werden soll.
    
    .EXAMPLE
    New-OU -OUName "Benutzer" -ParentOU $(Get-DomainDN)
    Erstellt die OU "Benutzer" im Root der Domain "example.com".

    .EXAMPLE
    New-OU -OUName "Administratoren" -ParentOU "OU=Benutzer,$(Get-DomainDN)"
    Erstellt die OU "Administratoren" in der OU "Benutzer" der Domain "example.com".

    .NOTES
    Erforderlich: Active Directory-Modul für PowerShell
    #>

    param (
        [string]$OUName,          # Name der zu erstellenden OU
        [string]$ParentOU         # Distinguished Name der übergeordneten OU
    )
    
    # Prüft, ob die OU bereits existiert
    if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $OUName } -SearchBase $ParentOU -ErrorAction SilentlyContinue)) {
        # Wenn die OU nicht existiert, wird sie erstellt
        New-ADOrganizationalUnit -Name $OUName -Path $ParentOU
        Write-Host "OU '$OUName' wurde erfolgreich erstellt."
    } else {
        # Wenn die OU bereits existiert, wird eine Nachricht ausgegeben
        Write-Host "OU '$OUName' existiert bereits."
    }
}

# Funktion zur Ermittlung des Distinguished Names der Domain
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

# Für weitere Hilfe 
# Get-Help New-OU -Examples

New-OU -OUName "Benutzer" -ParentOU $(Get-DomainDN)
New-OU -OUName "Administratoren" -ParentOU "OU=Benutzer,$(Get-DomainDN)"
New-OU -OUName "Dienste" -ParentOU "OU=Benutzer,$(Get-DomainDN)"
New-OU -OUName "Gruppen" -ParentOU Get-DomainDN
New-OU -OUName "DL_Gruppen" -ParentOU "OU=Gruppen,$(Get-DomainDN)"
New-OU -OUName "GG_Gruppen" -ParentOU "OU=Gruppen,$(Get-DomainDN)"
