# PS 2.3 v1.0 - AD-Benutzer, Gruppen und Computer erstellen und verwalten

# 1.Eine Hash-Tabelle für allgemeine Benutzerattribute erstellen
$PW = 'Pa$$w0rd'
$PSS = ConvertTo-SecureString -String $PW -AsPlainText -Force
$NewUserHT = @{}
$NewUserHT.AccountPassword       = $PSS
$NewUserHT.Enabled               = $true
$NewUserHT.PasswordNeverExpires  = $true
$NewUserHT.ChangePasswordAtLogon = $false

# 2. Erstellen Sie zwei neue Benutzer, fügen Sie der 
# allgeneinen Hash-Tabelle weitere Attribute hinzu
# Erster Benutzer
$NewUserHT.SamAccountName    = 'richardK'
$NewUserHT.UserPrincipalName = 'richardK@star.wars'
$NewUserHT.Name              = 'richardK'
$NewUserHT.DisplayName       = 'Richard Kammermeier (AD)'
New-ADUser @NewUserHT
# Zweiter Benutzer
$NewUserHT.SamAccountName    = 'sbG'
$NewUserHT.UserPrincipalName = 'sebastianG@star.wars'
$NewUserHT.Name              = 'Sebastian Gottlebe'
$NewUserHT.DisplayName       = 'Sebastian Gottlebe (AD)'
New-ADUser @NewUserHT

# 3. Erstellen Sie eine OU für AD und verschieben Sie Benutzer in diese OU
$OUHT = @{
    Name        = 'AD'
    DisplayName = 'AD Cluster Team'
    Path        = 'DC=star,DC=wars'
}
New-ADOrganizationalUnit @OUHT
$MHT1 = @{
    Identity   = 'CN=richardK,CN=Users,DC=star,DC=wars'
    TargetPath = 'OU=AD,DC=star,DC=wars'
}
Move-ADObject @MHT1
$MHT2 = @{
    Identity = 'CN=Sebastian Gottlebe,CN=Users,DC=star,DC=wars'
    TargetPath = 'OU=AD,DC=star,DC=wars'
}
Move-ADObject @MHT2

# 4. Erstellen Sie in der OU AD direkt einen dritten Benutzer
$NewUserHT.SamAccountName    = 'StefanS'
$NewUserHT.UserPrincipalName = 'StefanS@star.wars'
$NewUserHT.Description       = 'Fachlehrer Team'
$NewUserHT.Name              = 'Stefan Schiffmann'
$NewUserHT.DisplayName       = 'Stefan Schiffmann (AD)'
$NewUserHT.Path              = 'OU=AD,DC=star,DC=wars'
New-ADUser @NewUserHT

# 5. Erstellen Sie zwei Benutzer, die später wieder entfernt werden
# Erster Benutzer, der wieder entfernt wird
$NewUserHT.SamAccountName    = 'MLTemp1'
$NewUserHT.UserPrincipalName = 'MLTemp1@star.wars'
$NewUserHT.Name              = 'MLTemp1'
$NewUserHT.DisplayName       = 'Temporärer ML Kollege, der entfernt wird'
$NewUserHT.Path              = 'OU=AD,DC=star,DC=wars'
New-ADUser @NewUserHT
# Zweiter Benutzer, der wieder entfernt wird
$NewUserHT.SamAccountName    = 'MLTemp2'
$NewUserHT.UserPrincipalName = 'MLTemp2star.wars'
$NewUserHT.Name              = 'MLTemp2'
New-ADUser @NewUserHT

# 6. Sehen Sie die Benutzer an, die derzeit vorhanden sind
Get-ADUser -Filter *  -Property *| 
  Format-Table -Property Name, Displayname, SamAccountName

# 7. Benutzer via  Get | Remove entfernen
Get-ADUser -Identity 'CN=MLTemp1,OU=AD,DC=star,DC=wars' |
    Remove-ADUser -Confirm:$false

# 8. Direkt entfernen
$RUHT = @{
  Identity = 'CN=MLTemp2,OU=AD,DC=star,DC=wars'
  Confirm  = $false}
Remove-ADUser @RUHT

# 9. Einen Benutzer aktualisieren und anzeigen
$TLHT =@{
  Identity     = 'richardK'
  OfficePhone  = '4416835420'
  Office       = 'Landau i.d.P. HQ'
  EmailAddress = 'richardK@star.wars'
  GivenName    = 'Richard'
  Surname      = 'Kammermeier' 
  HomePage     = 'Https://gibt.es.nicht.itcoach.eu'
}
Set-ADUser @TLHT
Get-ADUser -Identity richardK -Properties * |
  Format-Table -Property DisplayName,Name,Office,
                         OfficePhone,EmailAddress 

# 10. Eine neue Gruppe erstellen
$NGHT = @{
 Name        = 'AD-Team'
 Path        = 'OU=AD,DC=star,DC=wars'
 Description = 'Alle Mitglieder des AD-Cluster-Teams'
 GroupScope  = 'DomainLocal'
}
New-ADGroup @NGHT


# 11. Alle Benutzer aus dem AD-Team in die OU AD verschieben
$SB = 'OU=AD,DC=star,DC=wars'
$ItUsers = Get-ADUser -Filter * -SearchBase $SB
Add-ADGroupMember -Identity 'AD-Team'  -Members $ItUsers

# 12. Mitglieder anzeigen
Get-ADGroupMember -Identity 'AD-Team' |
  Format-Table SamAccountName, DistinguishedName

# 13. Einen Computer in AD einfügen
$NCHT = @{
  Name                   = 'Wolf' 
  DNSHostName            = 'Wolf.star.wars'
  Description            = 'Der ist für Stefan'
  Path                   = 'OU=AD,DC=star,DC=wars'
  OperatingSystemVersion = 'Windows Server 2021 Data Center'
}
New-ADComputer @NCHT

# 14. Computerkonten anzeigen 
Get-ADComputer -Filter * -Properties * | 
  Format-Table Name, DNSHost*,LastLogonDate
