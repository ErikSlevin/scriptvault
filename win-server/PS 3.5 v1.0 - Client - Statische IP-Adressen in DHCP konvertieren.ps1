# PS 3.5 v1.0 - Client - Statische IP-Adressen in DHCP konvertieren
#
# Auf Client ausführen


# 1.Aktuelle IP-Adressinformationen abrufen:
$IPType = 'IPv4'
$Adapter = Get-NetAdapter |
    Where-Object Status -eq 'up'
$Interface = $Adapter |
    Get-NetIPInterface -AddressFamily $IPType
$IfIndex = $Interface.ifIndex
$IfAlias = $Interface.Interfacealias
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily $IPType

# 2. Für die Netzwerkschnittstelle festlegen, dass Adresse von DHCP geliefert wird:
Set-NetIPInterface -InterfaceIndex $IfIndex -DHCP Enabled

# 3. Die Ergebnisse testen:
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily $IPType