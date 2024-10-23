# PS 3.1 v1.0 - Neue Arten um altbekannte Dinge zu tun 
#
# Auf DC2 ausführen

# 1. Ipconfig vs neue Cmdlets

# Zwei Variationen der traditionellen Art
ipconfig.exe
ipconfig.exe /all

# Auf die neue Art
Get-NetIPConfiguration

# Verwandte Cmdlets - aber nicht für den Kurs...
Get-NetIPInterface
Get-NetAdapter

# 2. Einen Computer anpingen

# Auf die traditionelle Art 
Ping DC1.star.wars
# Auf die neue Art
Test-NetConnection DC1.star.wars

# Und ein paar Dinge, die Ping nicht kann!
Test-NetConnection DC1.star.wars -CommonTCPPort SMB
$ILHT = @{InformationLevel = 'Detailed'}
Test-NetConnection DC1.star.wars -port 389 @ILHT

# 3. Auf DC1 freigegebenen Ordner verwenden

# Die traditionelle Art, um einen freigegebenen Ordner zu verwenden
net use X:  \\DC1.star.wars\c$

# Die neue Art verwendet ein SMB-Cmdlet
New-SMBMapping -LocalPath 'Y:' -RemotePath \\DC1.star.wars\c$

# Prüfen, welche Freigaben verwendet werden: die klassische Art
net use

# und auf die neue Art
Get-SMBMapping

# 4. - Einen Ordner auf DC2 freigeben

# Zuerst auf die klassische Art freigeben
net share Windows=C:\windows
# und dann auf die neue Art 
New-SmbShare -Path C:\Windows -Name Windows2
# Auf die traditionelle Art anzeigen, was freigegeben wurde
net share
# und auf die neue Art
Get-SmbShare

# 5. Inhalt des DNS-Auflösungscache anzeigen 
# Auf die klassische Art 
ipconfig /displaydns
# auf die neue ARt
Get-DnsClientCache

# 6. DNS-Auflösungscache auf die klassische Art löschen
Ipconfig /flushdns
# Das ist die neue Art
Clear-DnsClientCache

# 7. DNS-Abfragen
Nslookup DC1.star.wars
Resolve-DnsName -Name DC1.star.wars  -Type ALL
#


< # undo
Get-SmbMapping x: | Remove-SmbMapping -force
Get-SmbMapping y: | Remove-SmbMapping -confirm:$false
Get-SMBSHARE Windows* | Remove-SMBShare -confirm:$false
>
