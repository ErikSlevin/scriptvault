# PS 3.3 v1.0 - DHCP-Server installieren und autorisieren
#
# Auf FileServer.star.wars ausführen

# 1. Das DHCP-Feature installieren
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# 2. Die Sicherheitsgruppen des DHCP-Servers hinzufügen
Add-DHCPServerSecurityGroup -Verbose

# 3.  DHCP wissen lassen, dass alles konfiguriert ist 
$RegHT = @{
Path  = 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12'
Name  = 'ConfigurationState'
Value = 2
}
Set-ItemProperty @RegHT

# 4. Den DHCP-Server in AD autorisieren
Add-DhcpServerInDC -DnsName FileServer.star.wars

# 5. DHCP-Server-Dienst neu starten
Restart-Service -Name DHCPServer –Force 
