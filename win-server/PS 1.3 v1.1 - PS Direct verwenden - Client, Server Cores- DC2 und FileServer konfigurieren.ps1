# PS 1.3 v1.1 - PS Direct verwenden - Client, Server Core DC2 und FileServer konfigurieren


# 1. Erstellen Sie für den lokalen Administrator ein Objekt mit Anmeldeinformationen:
$Ad   = 'Administrator'
$PS   = 'Pa$$w0rd'
$AdP  = ConvertTo-SecureString -String $PS -AsPlainText -Force
$T = 'System.Management.Automation.PSCredential'
$AdCred = New-Object -TypeName $T -ArgumentList $Ad,$AdP

#-------------------------------------------------------------------
$VMName = 'Client.star.wars'
#-------------------------------------------------------------------

# 2. Zeigen Sie Details zur VM Client.star.wars an:
Get-VM -Name "$VMName"

# 3. Führen Sie auf der VM einen Befehl aus, und geben Sie dabei den Namen der VM an:
$SBHT = @{
  VMName      = "$VMName"
  Credential  = $AdCred
  ScriptBlock = {hostname}
}
Invoke-Command @SBHT

# 4. Führen Sie einen Befehl aus und geben Sie dabei die VM ID an:
$VMID = (Get-VM -VMName "$VMName").VMId.Guid
$ICMHT = @{
  VMid        = $VMID 
  Credential  = $AdCred  
  ScriptBlock = {hostname}
}
Invoke-Command @ICMHT

# 5. Starten Sie eine PowerShell-Remoting-Sitzung mit der VM Client.star.wars:
Enter-PSSession -VMName "$VMName" -Credential $AdCred
    Get-CimInstance -Class Win32_ComputerSystem
    # DHCP-Client konfigurieren und Computer umbenennen:
    # 1.Aktuelle IP-Adressinformationen abrufen:
        $IPType = 'IPv4'
        $Adapter = Get-NetAdapter |
            Where-Object Status -eq 'up'
        $Interface = $Adapter |
            Get-NetIPInterface -AddressFamily $IPType
        $IfIndex = $Interface.ifIndex
        $IfAlias = $Interface.Interfacealias
        Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily $IPType
        # 2. IP-Adresse für DC1 festlegen
        $IPHT = @{
            InterfaceAlias = $IfAlias
            PrefixLength   = 24
            IPAddress      = '192.168.0.10'
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
        Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily $IPType
        # 5. Computer umbenennen:
        Rename-Computer -NewName Client
        # 6. Computer neu starten
        Restart-Computer -Force
Exit-PSSession

#-------------------------------------------------------------------
$VMName = 'DC2.star.wars'
#-------------------------------------------------------------------
# 2. Zeigen Sie Details zur VM Client.star.wars an:
Get-VM -Name "$VMName"

# 5. Starten Sie eine PowerShell-Remoting-Sitzung mit der VM DC2.star.wars:
Enter-PSSession -VMName "$VMName" -Credential $AdCred
    Get-CimInstance -Class Win32_ComputerSystem

    # 1.Aktuelle IP-Adressinformation für DC2 abrufen:
    $IPType = 'IPv4'
    $Adapter = Get-NetAdapter |
        Where-Object Status -eq 'Up'     |
	    Select -First 1
    $Interface = $Adapter |
        Get-NetIPInterface -AddressFamily $IPType
    $IfIndex = $Interface.ifIndex
    $IfAlias = $Interface.Interfacealias
    Get-NetIPAddress -InterfaceIndex $Ifindex -AddressFamily $IPType

    # 2. IP-Adresse für DC2 festlegen
    $IPHT = @{
        InterfaceAlias = $IfAlias
        PrefixLength   = 24
        IPAddress      = '192.168.0.2'
        DefaultGateway = '192.168.0.254'
        AddressFamily  = $IPType
    }
    New-NetIPAddress @IPHT | Out-Null

    # 3. Details für DNS-Server festlegen
    $CAHT = @{
        InterfaceIndex  = $IfIndex
        ServerAddresses = '192.168.0.2','192.168.0.1'
    }
    Set-DnsClientServerAddress  @CAHT 

    #Fernverwaltung aktivieren:
    Enable-PSRemoting -Force

    # 7. Computer umbenennen und neu starten:
    Rename-Computer DC2 -Restart 
Exit-PSSession


#-------------------------------------------------------------------
$VMName = 'FileServer.star.wars'
#-------------------------------------------------------------------
# 2. Zeigen Sie Details zur VM Client.star.wars an:
Get-VM -Name "$VMName"

# 5. Starten Sie eine PowerShell-Remoting-Sitzung mit der VM FileServer.star.wars:
Enter-PSSession -VMName "$VMName" -Credential $AdCred
    Get-CimInstance -Class Win32_ComputerSystem

    # 1.Aktuelle IP-Adressinformation für DC2 abrufen:
    $IPType = 'IPv4'
    $Adapter = Get-NetAdapter |
        Where-Object Status -eq 'Up'     |
	    Select -First 1
    $Interface = $Adapter |
        Get-NetIPInterface -AddressFamily $IPType
    $IfIndex = $Interface.ifIndex
    $IfAlias = $Interface.Interfacealias
    Get-NetIPAddress -InterfaceIndex $Ifindex -AddressFamily $IPType

    # 2. IP-Adresse für DC2 festlegen
    $IPHT = @{
        InterfaceAlias = $IfAlias
        PrefixLength   = 24
        IPAddress      = '192.168.0.3'
        DefaultGateway = '192.168.0.254'
        AddressFamily  = $IPType
    }
    New-NetIPAddress @IPHT | Out-Null

    # 3. Details für DNS-Server festlegen
    $CAHT = @{
        InterfaceIndex  = $IfIndex
        ServerAddresses = '192.168.0.2','192.168.0.1'
    }
    Set-DnsClientServerAddress  @CAHT 

    #Fernverwaltung aktivieren:
    Enable-PSRemoting -Force

    # 7. Computer umbenennen und neu starten:
    Rename-Computer FileServer -Restart 
Exit-PSSession