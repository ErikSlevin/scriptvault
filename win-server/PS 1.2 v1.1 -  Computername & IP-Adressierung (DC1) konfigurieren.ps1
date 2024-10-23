# PS 1.2 v1.1 -  Computername & IP-Adressierung (DC1) konfigurieren

#-----------------------------------------------------------------
# Auf DC1 ausführen
#-----------------------------------------------------------------

# 1. Aktuelle IP-Adressinformation für DC1 abrufen:
$IPType = 'IPv4'
$Adapter = Get-NetAdapter |
    Where-Object Status -eq 'Up'     |
	Select -First 1
$Interface = $Adapter |
    Get-NetIPInterface -AddressFamily $IPType
$IfIndex = $Interface.ifIndex
$IfAlias = $Interface.Interfacealias
Get-NetIPAddress -InterfaceIndex $Ifindex -AddressFamily $IPType

# 2. IP-Adresse für DC1 festlegen
$IPHT = @{
    InterfaceAlias = $IfAlias
    PrefixLength   = 24
    IPAddress      = '192.168.0.1'
    DefaultGateway = '192.168.0.254'
    AddressFamily  = $IPType
}
New-NetIPAddress @IPHT | Out-Null

# 3. Details für DNS-Server festlegen
$CAHT = @{
    InterfaceIndex  = $IfIndex
    ServerAddresses = '192.168.0.1','192.168.0.2'
}
Set-DnsClientServerAddress  @CAHT

# 4. Neue Konfiguration testen
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4
#Test-NetConnection -ComputerName DC1.star.wars
#Resolve-DnsName -Name DC1.star.wars -Server DC1.Reskit.Org |
#  Where-Object Type -eq 'A'


# Rückgängig
#$IPHT = @{
#    InterfaceAlias = $IfAlias
#    PrefixLength   = 24
#    IPAddress      = ''alte Adresse
#    DefaultGateway = ''alte Adresse
#    AddressFamily  = $IPType
#}
#New-NetIPAddress @IPHT   

# 5. Computer umbenennen:
Rename-Computer -NewName DC1
# 6. Computer neu starten
Restart-Computer -Force



