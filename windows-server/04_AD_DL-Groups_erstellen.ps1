#--------------------------------#
#      DL GRUPPEN  ERSTELLEN     #
#--------------------------------#

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