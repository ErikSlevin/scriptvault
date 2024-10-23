# PS 2.2 v1.0 - DC2 - AD mit DNS installieren

### auf DC2 ausführen
#   Geht davon aus, dass DC1 jetzt ein Domänencontroller ist, 
#   DC2 (Basis Server Core) wird zunächst ein Member-Server vor der AD Installation 

# 1. Prüfen, ob DC1 aufgelöst werden kann und ob DC1  
#    über Ports 445 und 389 von DC2 aus erreichbar ist
Resolve-DnsName -Name DC1.star.wars -Type A
Test-NetConnection -ComputerName DC1.star.wars -Port 445
Test-NetConnection -ComputerName DC1.star.wars -Port 389

# 2. Computer zur Domäne hinzufügen und neustarten
$USW = "administrator@star.wars"
$PSS = ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force
$CredSW = New-Object system.management.automation.PSCredential $USW,$PSS
Add-Computer -Credential $CredSW -DomainName star.wars -Force -Restart TRUE

# 3. Computer umbenennen und neu starten:
Rename-Computer DC2 -Restart 

# 4. AD DS-Features auf DC2 installieren
$Features = 'AD-Domain-Services', 'DNS','RSAT-DHCP', 'Web-Mgmt-Tools'
Install-WindowsFeature -Name $Features

# 5. DC2 heraufstufen zum DC in der Domäne star.wars
$USW = "administrator@star.wars"
$PSS = ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force
$CredSW = New-Object system.management.automation.PSCredential $USW,$PSS
$IHT =@{
  DomainName                    = 'star.wars'
  SafeModeAdministratorPassword = $PSS
  SiteName                      = 'Default-First-Site-Name'
  NoRebootOnCompletion          = $true
  Force                         = $true
} 
Install-ADDSDomainController @IHT -Credential $CredSW

# 6. DC2 neu starten	
Restart-Computer -Force

# 7.. Nach den Neustart auf DC1 anmelden und Gesamtstruktur ansehen 
Get-AdForest | 
  Format-Table -Property *master*,globaL*,Domains

            
