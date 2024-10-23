# PS 2.4 v1.0 - Benutzer aus einer CSV-Datei in AD importieren

# 0. CSV-Datei erstellen
$CSVDATA = @'
Firstname, Initials, Lastname, UserPrincipalName, Alias, Description, Password
Luke,LS,Skywalker, SKM, Sylvester, JungerJedi, $Yedi4Ever&Ever
Obi Wan,OWK, Kenobi, OWK, ObiWan, Lehrer, $Yedi4Ever&Ever
Yoda, Y, , BBJB,Yoda, MasterInstructor, $Yedi4Ever&Ever
Mace, MW, Windu, Mace, Mace, KeineAhnungWerDasIst, $Yedi4Ever&Ever
'@
$CSVDATA | Out-File -FilePath C:\PS\Benutzer.Csv

# 1. Eine CSV-Datei importieren, die Details zu den Benutzern enthält, 
#    die Sie dem AD hinzufügen wollen:
$Users = Import-CSV -Path C:\PS\Benutzer.Csv | 
  Sort-Object  -Property Alias
$users | Sort-Object -Property Alias | Format-Table

# 2. Benutzer einzeln hinzufügen 
ForEach ($User in $Users) {
#    Eine Hashtabelle mit Eigenschaften erstellen, die dem neu 
#    erstellten Benutzer zugewiesen werden
$Prop = @{}
#    Werte eintragen
$Prop.GivenName         = $User.Firstname
$Prop.Initials          = $User.Initials
$Prop.Surname           = $User.Lastname
$Prop.UserPrincipalName =
  $User.UserPrincipalName+"@star.wars"
$Prop.Displayname       = $User.firstname.trim() + " " +
  $user.lastname.trim()
$Prop.Description       = $User.Description
$Prop.Name              = $User.Alias
$PW = ConvertTo-SecureString -AsPlainText $user.password -Force
$Prop.AccountPassword   = $PW
#    Um sicher zu sein!
$Prop.ChangePasswordAtLogon = $true
#    Jetzt den Benutzer erstellen 
New-ADUser @Prop -Path 'OU=AD,DC=star,DC=wars' -Enabled:$true
#   Abschließend den neu erstellten Benutzer anzeigen
"User $($Prop.Displayname) wurde erstellt"
}



### Die Benutzer entfernen, die in diesem Script erstellt wurden

$users = Import-Csv C:\PS\Benutzer.csv
foreach ($User in $Users)
{
  Get-ADUser -Identity $user.alias | remove-aduser -Confirm:$false
}
