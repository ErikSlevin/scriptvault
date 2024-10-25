#--------------------------------#
#         Active Directory       #
#--------------------------------#    

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$DomainName = "pod03.spielwiese.intern"
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "$DomainName" `
-DomainNetbiosName "POD03" `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true `
-SafeModeAdministratorPassword:(ConvertTo-SecureString "Passw0rd" -AsPlainText -Force)

# DC2
Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$false `
-Credential (Get-Credential) `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainName $DomainName `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-ReplicationSourceDC "dc01" + $DomainName  `
-SiteName "Default-First-Site-Name" `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true
