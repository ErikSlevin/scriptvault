# PS 3.6 v1.0 - DHCP-Failover und Lastenausgleich konfigurieren

# Auf DC2 ausführen

# 1. Auf DC2 das Feature DHCP-Server installieren:
$FHT = @{
  Name         = 'DHCP','RSAT-DHCP' 
  ComputerName =  'DC2.star.wars'}
Install-WindowsFeature @FHT

# 2. DHCP darüber informieren, dass alles konfiguriert ist:
$IPHT = @{
  Path   = 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12'
  Name   = 'ConfigurationState'
  Value  = 2
}
Set-ItemProperty @IPHT

# 3. Den DHCP-Server in AD autorisieren und die Ergebnisse anzeigen:
Add-DhcpServerInDC -DnsName DC2.star.wars

# 4. Die in der Domäne autorisierten DHCP-Server anzeigen lassen:
Get-DhcpServerInDC

# 5. Failover und Lastenausgleich konfigurieren:
$FHT= @{
  ComputerName       = 'FileServer.star.wars'
  PartnerServer      = 'DC2.star.wars'
  Name               = 'FileServer-DC2'
  ScopeID            = '192.168.0.0'
  LoadBalancePercent = 60
  SharedSecret       = 'jed1sRg00d!'
  Force              = $true
}
Add-DhcpServerv4Failover @FHT
-

# 6. Aktice Leases im Bereich anzeigen (von beiden Servern!)
'FileServer', 'DC2' |
    ForEach-Object {Get-DhcpServerv4Lease -ScopeID 192.168.0.0 -ComputerName $_}

# 7. Serverstatistiken von beiden Servern abrufen
'FileServer', 'DC2' |
ForEach-Object {
    Get-DhcpServerv4ScopeStatistics -ComputerName $_} 
