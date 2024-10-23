# PS 3.4 v1.0 - DHCP-Bereiche konfigurieren

# Auf FileServer.star.wars ausführen

# 1. Einen DHCP-Bereich erstellen
$SHT = @{
  Name         = 'starwars'
  StartRange   = '192.168.0.11'
  EndRange     = '192.168.0.100'
  SubnetMask   = '255.255.255.0'
  ComputerName = 'FileServer.star.wars'
}
Add-DhcpServerV4Scope @SHT

# 2. Vorhandene Bereiche vom Server abrufen
Get-DhcpServerv4Scope -ComputerName FileServer.star.wars

# 3. Optionswerte festlegen
$OHT = @{
  ComputerName = 'FileServer.star.wars'
  DnsDomain = 'star.wars'
  DnsServer = '192.168.0.1','192.168.0.2'
}
Set-DhcpServerV4OptionValue @OHT 

# 4. Festgelegte Optionen abrufen
Get-DhcpServerv4OptionValue -ComputerName FileServer.star.wars