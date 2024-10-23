# PS 2.6 v1.0 - Bericht zu AD-Benutzern

# 1. Die Funktion Get-ReskitUser definieren
#    Die Funktion gibt Benutzerobjekte in star.wars zurück
Function Get-StarwarsUser {
# PDC-Emulator-DC holen
$PrimaryDC = Get-ADDomainController -Discover -Service PrimaryDC
# Benutzer abrufen 
$ADUsers = Get-ADUser -Filter * -Properties * -Server $PrimaryDC
# Benutzer in Schleife durchlaufen und Hash-Tabelle $Userinfo erstellen:
Foreach ($ADUser in $ADUsers) {
    # Create a userinfo HT
    $UserInfo = [Ordered] @{}
    $UserInfo.SamAccountname = $ADUser.SamAccountName
    $Userinfo.DisplayName    = $ADUser.DisplayName
    $UserInfo.Office         = $ADUser.Office
    $Userinfo.Enabled        = $ADUser.Enabled
    $userinfo.LastLogonDate  = $ADUser.LastLogonDate
    $UserInfo.ProfilePath    = $ADUser.ProfilePath
    $Userinfo.ScriptPath     = $ADUser.ScriptPath
    $UserInfo.BadPWDCount    = $ADUser.badPwdCount
    New-Object -TypeName PSObject -Property $UserInfo
    }
} # Ende der Funktion

# 2. Benutzer abrufen
$SWUsers = Get-StarwarsUser

# 3. Berichtsheader erstellen
$RKReport = ''
$RKReport += "*** star.wars-AD-Bericht`n"
$RKReport += "*** Erstellt [$(Get-Date)]`n"
$RKReport += "*******************************`n`n"

# 4. Bericht zu deaktivierten Benutzerkonten
$SWReport += "*** Deaktivierte Benutzerkonten`n"
$SWReport += $SWUsers |
    Where-Object {$_.Enabled -NE $true} |
        Format-Table -Property SamAccountName, Displayname |
            Out-String

# 5. Bericht zu Benutzern, die sich in der letzten Zeit nicht angemeldet haben
$OneWeekAgo = (Get-Date).AddDays(-7)
$SWReport += "`n*** Benutzer, die sich seit $OneWeekAgo nicht angemeldet haben`n"
$SWReport += $SWUsers |
    Where-Object {$_.Enabled -and $_.LastLogonDate -le $OneWeekAgo} |
        Sort-Object -Property LastlogonDate |
            Format-Table -Property SamAccountName,lastlogondate |
                Out-String

# 6. Benutzer mit einer großen Anzahl Anmeldefehlversuchen 
$SWReport += "`n*** Große Anzahl von Anmeldefehlversuchen`n"
$SWReport += $SWUsers | Where-Object BadPwdCount -ge 5 |
  Format-Table -Property SamAccountName, BadPwdCount |
    Out-String

# 7. Eine weitere Überschrift für diesen Teil des Berichts erstellen 
#    und ein leeres Array für die privilegierten Benutzerkonten erstellen 
$SWReport += "`n*** Bericht zu privilegierten Benutzern`n"
$PUsers = @()

# 8. Mitglieder der Gruppen Organisations-Admins/Domänen-Admins/Schema-Admins
#    abrufen und an Array $PUsers anhängen
# Mitglieder der Gruppe Organisations-Admins abrufen 
$Members = Get-ADGroupMember -Identity 'Organisations-Admins' -Recursive |
    Sort-Object -Property Name
$PUsers += foreach ($Member in $Members) {
    Get-ADUser -Identity $Member.SID -Properties * |
        Select-Object -Property Name,
               @{Name='Group';expression={'Organisations-Admins'}},
               whenCreated,LastlogonDate
}
# Mitglieder der Gruppe Domänen-Admins abrufen 
$Members = 
  Get-ADGroupMember -Identity 'Domänen-Admins' -Recursive |
    Sort-Object -Property Name
$PUsers += Foreach ($Member in $Members)
    {Get-ADUser -Identity $member.SID -Properties * |
        Select-Object -Property Name,
                @{Name='Group';expression={'Domänen-Admins'}},
                WhenCreated, Lastlogondate,SamAccountName
}
# Mitglieder der Gruppe Schema-Admins abrufen
$Members = 
  Get-ADGroupMember -Identity 'Schema-Admins' -Recursive |
    Sort-Object Name
$PUsers += Foreach ($Member in $Members) {
    Get-ADUser -Identity $member.SID -Properties * |
        Select-Object -Property Name,
            @{Name='Group';expression={'Schema-Admins'}}, `
            WhenCreated, Lastlogondate,SamAccountName
}

# 9. Liste mit privilegierten Benutzern an Bericht anhängen
$SWReport += $PUsers | Out-String

# 10. Den Bericht anzeigen
$SWReport