#--------------------------------#
# Grundkonfiguration durchführen #
#--------------------------------#
sconfig.cmd
    # 02 | Hostname - {dc01} - neustarten [nein]
    # 04 - 1 | Remoteverwaltung aktivieren
    # 04 - 3 | Serverantwort für Ping konfigurieren [ja]
    # 07 | Remotedesktop | [a]ktivieren - [2]geringere Sicherheit
    # 08 | IP-Konfiguration - {ID} auswählen - {IP} & {DNS}
    # 13 | Neustarten

#--------------------------------#
#         Active Directory       #
#--------------------------------#    
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$DomainName = "pod03.spielwiese.intern"
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "$DomainName" `
-DomainNetbiosName "POD03" `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true `
-SafeModeAdministratorPassword:(ConvertTo-SecureString "Passw0rd" -AsPlainText -Force)

# DC2
Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$false `
-Credential (Get-Credential) `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainName $DomainName `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-ReplicationSourceDC "dc01" + $DomainName  `
-SiteName "Default-First-Site-Name" `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true


#--------------------------------#
#         AD-USER  ERSTELLEN     #
#--------------------------------#

$DomainName = "pod03.spielwiese.intern"
$users = @(
    'Max Müller',
    'Sophie Schmidt',
    'John Schneider',
    'Emily Fischer',
    'Lukas Weber',
    'Anna Meyer',
    'Michael Wagner',
    'Laura Becker',
    'Tim Hoffmann',
    'Julia Koch'
)

# Domain-Variable

$userObjects = @()
$heutigesDatum = Get-Date -Format "dd.MM.yyyy"
function Remove-SpecialCharacters {
    param ($inputString)
    $outputString = $inputString
    $outputString = $outputString -replace 'ä', 'ae'
    $outputString = $outputString -replace 'ö', 'oe'
    $outputString = $outputString -replace 'ü', 'ue'
    $outputString = $outputString -replace 'ß', 'ss'
    $outputString = $outputString -replace '[^a-zA-Z0-9]', ''
    return $outputString
}

foreach ($name in $users) {
    $splitName = $name -split ' '
    $vorname = $splitName[0]
    $nachname = $splitName[1]
    $vornameClean = Remove-SpecialCharacters $vorname
    $nachnameClean = Remove-SpecialCharacters $nachname
    $samAccountName = ($vornameClean.Substring(0,1) + $nachnameClean).ToLower()
    $userPrincipalName = "$samAccountName@$DomainName"
    $userObjects += [PSCustomObject]@{
        Vorname            = $vorname
        Nachname           = $nachname
        SamAccountName     = $samAccountName
        UserPrincipalName  = $userPrincipalName
        Name               = $samAccountName
        DisplayName        = "$vornameClean $nachnameClean"
        EmailAddress       = $userPrincipalName
        Description        = "Erstellt am " + $heutigesDatum
    }
}

$userObjects | Format-Table
$confirmation = Read-Host "Möchtest du die angezeigten Benutzer in der Domain '$DomainName' erstellen? (Ja/Nein)"

if ($confirmation -eq "Ja") {
    foreach ($user in $userObjects) {
        try {
            $password = ConvertTo-SecureString "Passw0rd" -AsPlainText -Force
            New-ADUser -SamAccountName $user.SamAccountName `
                       -UserPrincipalName $user.UserPrincipalName `
                       -Name $user.DisplayName `
                       -GivenName $user.Vorname `
                       -Surname $user.Nachname `
                       -DisplayName $user.DisplayName `
                       -EmailAddress $user.EmailAddress `
                       -Description $user.Description `
                       -Enabled $true `
                       -AccountPassword $password `
                       -PasswordNeverExpires $false `
                       -PassThru | Out-Null
            Write-Host -ForegroundColor Green "$($user.DisplayName) ($($user.SamAccountName)) erstellt."
        } catch {
            Write-Host "Fehler: $($user.DisplayName): $_"
        }
    }
} else {
    Write-Host "Keine Benutzer wurden erstellt."
}

#--------------------------------#
#      DL GRUPPEN  ERSTELLEN     #
#--------------------------------#

# Domain-Name
$DomainName = "pod03.spielwiese.intern"

# Liste der Freigabenamen
$Freigabenamen = @(
    'Transfer_KpChef',
    'Transfer_KpEinsOffz',
    'Transfer_KpFw',
    'S1 Abteilung',
    'S2 Abteilung',
    'S3 Abteilung',
    '1_Kompanie',
    '2_Kompanie',
    '3_Kompanie'
)

# Definiere die OU-Variable
$OrganizationalUnit = "CN=Users"  # Beispiel 
$domain = Get-ADDomain

$DomainFQDN = "$OrganizationalUnit,DC=$($domain.DnsRoot.Replace('.', ',DC='))"
$confirmation = Read-Host "Der FQDN der Domain ist: $DomainFQDN - Richtig? (Ja/Nein)"
if ($confirmation -ne "Ja") {
    Write-Host "Das Skript wird beendet."
    return
}
$Suffixe = @("R", "RW", "RX", "X")
$GruppenListe = @()
foreach ($Freigabename in $Freigabenamen) {
    foreach ($Suffix in $Suffixe) {
        $Groupname = "DL_$Freigabename" + "_" + "$Suffix"
        switch ($Suffix) {
            "R"  { $Beschreibung = "Lesen für $Freigabename" }
            "RW" { $Beschreibung = "Schreiben für $Freigabename" }
            "RX" { $Beschreibung = "Ändern für $Freigabename" }
            "X"  { $Beschreibung = "Vollzugriff für $Freigabename" }
        }
        $GruppenListe += [PSCustomObject]@{
            Groupname    = $Groupname
            FQDN         = $DomainFQDN
            Beschreibung = $Beschreibung
        }
    }
}
$GruppenListe | Format-Table
$createGroupsConfirmation = Read-Host "Möchtest du die oben angezeigten Gruppen erstellen? (Ja/Nein)"
if ($createGroupsConfirmation -ne "Ja") {
    Write-Host "Keine Gruppen wurden erstellt. Das Skript wird beendet."
    return
}
foreach ($gruppe in $GruppenListe) {
    try {      
        if (-not (Get-ADGroup -Filter "Name -eq '$($gruppe.Groupname)'")) {
            New-ADGroup -Name $gruppe.Groupname `
                        -DisplayName $gruppe.Groupname `
                        -GroupScope DomainLocal `
                        -GroupCategory Security `
                        -Description $gruppe.Beschreibung `
                        -Path $gruppe.FQDN
            Write-Host -ForegroundColor Green "$($gruppe.Groupname) erfolgreich erstellt."
        } else {
            Write-Host -ForegroundColor Yellow "$($gruppe.Groupname) existiert bereits."
        }
    } catch {
        Write-Host -ForegroundColor Red "Fehler beim Überprüfen oder Erstellen der Gruppe: $($gruppe.Groupname) - $_"
    }
}


#--------------------------------#
#         OU  ERSTELLEN          #
#--------------------------------#

# Hierarchische Struktur der Organisationen
$organisationArray = @{}

# Hinzufügen von Organisationen und ihren Kompanien/Abteilungen
$organisationArray["1.Bataillon"] = @{
    "1.Kompanie" = @("User", "Groups", "Computer")
    "2.Kompanie" = @("User", "Groups", "Computer")
}

$organisationArray["2.Bataillon"] = @{
    "1.Kompanie" = @("User", "Groups", "Computer")
    "2.Kompanie" = @("User", "Groups", "Computer")
}

$organisationArray["3.Bataillon"] = @{
    "1.Kompanie" = @()  # Keine weiteren Unterebenen
}

foreach ($organisation in $organisationArray.Keys) {
    Write-Host -ForegroundColor Green "├── $organisation"
    foreach ($kompanie in $organisationArray[$organisation].Keys) {
        Write-Host -ForegroundColor DarkGray "│  ├── $kompanie"
        foreach ($abteilung in $organisationArray[$organisation][$kompanie]) {
            Write-Host -ForegroundColor DarkGray "│  │   ├─── $abteilung"
        }
    }
}
