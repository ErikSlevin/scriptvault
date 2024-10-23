# PS 1.4 v1.0 - Fernverwaltung

# Powershell Remoting in Arbeitsgruppenumgebungen:

# 1. Auf FileServer (Remote Computer): Powershell Remoting einschalten:
#    (als Administrator ausführen)
# Powershell in cmd.exe laden:
powershell
Enable-PSRemoting -SkipNetworkProfileCheck -Force

        # Bei Rechte-Problemen: 
        # PS C:\Users\Administrator> winrm quickconfig
            # Der WinRM-Dienst wird auf diesem Computer bereits ausgeführt.
            # WinRM wurde nicht für Verwaltungsremotezugriff auf diesen Computer konfiguriert.
            # Folgende Änderungen müssen durchgeführt werden:
            # # Konfigurieren Sie "LocalAccountTokenFilterPolicy" so, dass lokalen Benutzern remote Administratorrechte gewährt werden.
            # Diese Änderungen durchführen [y/n]?

# 2. Auf DC1 (Lokaler Computer): 
#       ".. der Zielcomputer muss der TrustedHosts-Konfigurationseinstellung hinzugefügt werden.."
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.0.2" -Force
#       bzw. falls auf mehrere Externe Rechner zugegriffen werden muss:
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

Get-Item WSMan:\localhost\Client\TrustedHosts

# 3. von DC1 aus Remote-Session aufbauen: 
Enter-PSSession -Computername 192.168.0.3
#        [192.168.0.3]: PS C:\Users\Administrator\Documents>
         [192.168.0.3]: PS C:\Users\Administrator\Documents> ipconfig
#        Windows-IP-Konfiguration
#        Ethernet-Adapter Ethernet:
#        
#           Verbindungsspezifisches DNS-Suffix: 
#           Verbindungslokale IPv6-Adresse  . : fe80::fc1c:8b51:4daa:d8d1%3
#           IPv4-Adresse  . . . . . . . . . . : 192.168.0.3
#           Subnetzmaske  . . . . . . . . . . : 255.255.255.0
#           Standardgateway . . . . . . . . . : 192.168.0.254
#        
#        Tunneladapter isatap.{5E99D55C-CB2B-420C-A7F6-9B5C6EFA2447}:
#        
#           Medienstatus. . . . . . . . . . . : Medium getrennt
#           Verbindungsspezifisches DNS-Suffix: 
#        
         [192.168.0.3]: PS C:\Users\Administrator\Documents> exit-pssession
PS C:\Users\Administrator>  