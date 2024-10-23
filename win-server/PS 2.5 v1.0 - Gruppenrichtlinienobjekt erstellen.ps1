# PS 2.5 v1.0 - Gruppenrichtlinienobjekt erstellen

#######################################
# Quellen für weitere Einstellungen:
# https://www.maketecheasier.com/registry-values-for-group-policy-settings-windows/
# https://www.microsoft.com/en-us/download/details.aspx?id=25250
# https://social.technet.microsoft.com/Forums/windowsserver/en-US/e16eefbe-5d33-4100-a150-1eaaae799420/gpo-list-with-registry-settings
# https://gpsearch.azurewebsites.net/#4840
# https://docs.microsoft.com/en-us/powershell/module/grouppolicy/get-gpregistryvalue?view=windowsserver2022-ps&viewFallbackFrom=win10-ps
# https://sdmsoftware.com/group-policy-videos/find-all-registry-settings-managed-in-a-gpo/
#######################################


# 1. Gruppenrichtlinienobjekt erstellen 
$Pol = 
  New-GPO -Name star.wars-WIN-V1.0-B-Basis-kein-Papierkorb -Comment "Papierkorbsymbol vom Desktop entfernen" -Domain star.wars

# 2. Sicherstellen, dass die Computer- und Benutzereinstellungen aktiviert sind
$Pol.GpoStatus = 'AllSettingsEnabled'

# 3. Die Richtlinie  konfigurieren
 
$EPHT1= @{
  Name   = 'star.wars-WIN-V1.0-B-Basis-kein-Papierkorb'
  Key    = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
  ValueName = 'ExecutionPolicy'
  Value  = 'NoPropertiesRecycleBin' 
  Type   = 'String'
}
Set-GPRegistryValue @EPHT1 | Out-Null


# 4. Die GPO mit der OU AD verknüpfen
$GPLHT1 = @{
  Name     = 'star.wars-WIN-V1.0-B-Basis-kein-Papierkorb'
  Target   = 'OU=AD,DC=star,DC=wars'
}
New-GPLink @GPLHT1 | Out-Null

# 5. Die GPOs der Domäne anzeigen
Get-GPO -All -Domain star.wars |
  Sort -Property DisplayName |
    Format-Table -Property Displayname, Description, GpoStatus

# 6. Einen GPO-Bericht erzeugen und anzeigen
$RPath = 'C:\PS\GPOReport1.HTML'
Get-GPOReport -Name 'star.wars-WIN-V1.0-B-Basis-kein-Papierkorb' -ReportType Html -Path $RPath
Invoke-Item -Path $RPath

# Aktionen fürs Testen rückgängig machen

Remove-GPLink -Name 'star.wars-WIN-V1.0-B-Basis-kein-Papierkorb'  -Target 'OU=AD,DC=star,DC=wars'
Get-GPO 'star.wars-WIN-V1.0-B-Basis-kein-Papierkorb' | Remove-GPO
Get-GPO -Domain 'star.wars' -All |
  Format-Table -Property DisplayName, GPOStatus, Description