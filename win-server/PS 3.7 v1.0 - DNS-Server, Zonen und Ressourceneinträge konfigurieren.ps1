# PS 3.7 v1.0 - DNS-Server, Zonen und Ressourceneinträge konfigurieren

# Auf DC1 und Client ausführen
# Verwendet DC2

# 0. Vorbereitungen 
$PSS = ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force
$NewUserHT = @{
    AccountPassword       = $PSS
    Enabled               = $true
    PasswordNeverExpires  = $true
    ChangePasswordAtLogon = $false
    SamAccountName        = 'DNSADMIN'
    UserPrincipalName     = 'DNSADMIN@star.wars'
    Name                  = 'DNSADMIN'
    DisplayName           = 'StarWars DNS Admin'
}
New-ADUser @NewUserHT

# Zu Organisations- und Domain Admin Gruppen hizufügen
$GRPN = 'CN=Enterprise Admins,CN=Users,DC=star,DC=wars',
         'CN=Domain Admins,CN=Users,DC=star,DC=wars'
$PMHT = @{
    Identity = 'CN=DNSADMIN,CN=Users,DC=star,DC=wars'
    MemberOf = $GRPN
}
Add-ADPrincipalGroupMembership @PMHT
# Sicherstellen, dass der Benutzer hinzugefügt wurde 
Get-ADUser -LDAPFilter '(Name=DNSADMIN)'

# Das Hauptskript beginnt hier

# 1. DNS-Server-Dienst auf DC2 hinzufügen
Install-WindowsFeature -Name DNS -ComputerName Dc2.star.wars

# 2. Prüfen, ob DC1 star.wars zu DC2 repliziert wurde, nachdem DNS installiert ist
$DnsSrv = 'DC2.star.wars'
Resolve-DnsName -Name DC1.star.wars -Type A -Server $DnsSrv

# 3. Den neuen DNS-Server zu den DHCP-Optionen hinzufügen
$OHT = @{
  ComputerName = 'DC1.star.wars'
  DnsDomain    = 'star.wars'
  DnsServer    = '192.168.0.1','192.168.0.2'
}
Set-DhcpServerV4OptionValue @OHT 


# 4. Optionen auf DC1 überprüfen
Get-DhcpServerv4OptionValue | Format-Table -AutoSize


# 5. Jetzt die IP-Konfiguration auf CLient prüfen
#    Auf CLient ausführen
Get-DhcpServerv4OptionValue | Format-Table -AutoSize

# 6. Eine neue primäre Forward-DNS-Zone erstellen
$ZHT = @{
  Name              = 'PSRezepte.star.wars'
  ReplicationScope  = 'Forest'
  DynamicUpdate     = 'Secure'
  ResponsiblePerson = 'DNSADMIN.star.wars'
}
Add-DnsServerPrimaryZone @ZHT

# 7. Eine neue primäre Rervese-Lookup-Domain (fürIPv4) erstellen 
$PSHT = @{
  Name              = '0.168.192.in-addr.arpa'
  ReplicationScope  = 'Forest'
  DynamicUpdate     = 'Secure'
  ResponsiblePerson = 'DNSADMIN.star.wars.'
}
Add-DnsServerPrimaryZone @PSHT


# 8. Die beiden Zonen von DC1 aus prüfen 
Get-DNSServerZone -Name 'PSRezepte.star.wars', '0.168.192.in-addr.arpa'

# 9. Einen A-Ressourceneintrag (Host) zu PSRezepte.star.wars hinzufügen und Ergebnisse abrufen:
$RRHT1 = @{
  ZoneName      =  'PSRezepte.star.wars'
  A              =  $true
  Name           = 'Daheim'
  AllowUpdateAny =  $true
  IPv4Address    = '192.168.0.222'
  TimeToLive     = (30 * (24 * 60 * 60))  # 30 Tage in Sekunden
}
Add-DnsServerResourceRecord @RRHT1

# 10. Ergebnise der Ressourceneinträge in der Zone PSRezepte.star.wars prüfen
$Zname = 'PSRezepte.star.wars'
Get-DnsServerResourceRecord -ZoneName $Zname -Name 'home'

# 11. Reverselookup-Zone überprüfen
$RRH = @{
  ZoneName     = '0.168.192.in-addr.arpa'
  RRType       = 'Ptr'
  ComputerName = 'DC2'
}
Get-DnsServerResourceRecord @RRH


# 12. Einen Ressourceneintrag des Typs A zur Zone star.wars hinzufügen:
$RRHT2 = @{
  ZoneName       = 'star.wars'
  A              =  $true
  Name           = 'mail'
  CreatePtr      =  $true
  AllowUpdateAny = $true
  IPv4Address    = '192.168.0.223'
  TimeToLive     = '21:00:00'
}
Add-DnsServerResourceRecord  @RRHT2
$MXHT = @{
  Preference     = 10 
  Name           = '.'
  TimeToLive     = '1:00:00'
  MailExchange   = 'mail.star.wars'
  ZoneName       = 'star.wars'
}
Add-DnsServerResourceRecordMX @MXHT

$GHT = @{
  ZoneName = 'star.wars'
  Name     = '@'
  RRType   = 'Mx'
}
Get-DnsServerResourceRecord  @GHT


# 13. Den DNS-Dienst auf DC2 testen 
Test-DnsServer -IPAddress 192.168.0.2 -Context DnsServer
Test-DnsServer -IPAddress 192.168.0.2 -Context RootHints
Test-DnsServer -IPAddress 192.168.0.2 -ZoneName 'star.wars' 