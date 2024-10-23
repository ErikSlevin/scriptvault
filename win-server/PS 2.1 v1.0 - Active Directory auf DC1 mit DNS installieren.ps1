# PS 2.1 v1.0 - Active Directory auf DC1 mit DNS installieren

# Dieses Rezept verwendet DC1 und DC2 der Domäne star.wars
# Das Rezept beginnt bei DC1 und verwendet dann DC2.
# DC1 ist anfänglich ein Arbeitsgruppenserver, den Sie in einen
# Domänencontroller mit DNS konvertieren.
# In PS 2.1a anschließend konvertieren Sie DC2 (ein Member-Server der Domäne)
# in einen DC und installieren dort ebenfalls DNS.


### PS 2.1 - Teil 1 - auf DC1 ausführen

# 1. Das Feature Active Directory Domänendienste und die Verwaltungstools installieren
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 2. DC1 as Rootserver der Gesamstruktur installieren (DC1.star.wars)
$PSSHT = @{
  String      = 'Pa$$w0rd'
  AsPlainText = $true
  Force       = $true
}
$PSS = ConvertTo-SecureString @PSSHT
$ADHT = @{
  DomainName                    = 'star.wars'
  SafeModeAdministratorPassword = $PSS
  InstallDNS                    = $true
  DomainMode                    = 'WinThreshold'
  ForestMode                    = 'WinThreshold'
  Force                         = $true
  NoRebootOnCompletion          = $true
}
Install-ADDSForest @ADHT

# 3. Computer neu starten
Restart-Computer -Force

# 4. Nach dem Neustart auf DC1 als star\Administrator anmelden, dann 
Get-ADRootDSE |
  Format-Table -Property dns*, *functionality