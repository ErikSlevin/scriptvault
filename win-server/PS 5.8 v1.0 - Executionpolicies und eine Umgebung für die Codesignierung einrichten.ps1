# PS 1.5 v1.0 - Executionpolicies und eine Umgebung für die Codesignierung einrichten
# Auf CLient ausführen 

# Teil 1: ExecutionPolicies
#
# ExecutionPolicies legen fest, wann ein Script ausgeführt werden darf:
#     Unrestricted   -  Skripte werden ausgeführt. Bei Skripten 
#                       nicht vertrauenswürdiger Quellen erfolgt eine Abfrage
#     RemoteSigned   -  Alle Skripte fremder Quellen müssen digital von einem vertrauenswürdigen 
#                       Herausgeber signiert sein. Lokale Skripte werden ausgeführt
#     AllSigned      -  Jedes Skript muss von einem vertrauenswürdigen Herausgeber signiert sein
#     restricted     -  Standardwert; es werden keine Skripte ausgeführt. 
#                       Die PowerShell kann nur interaktiv verwendet werden

Set-ExecutionPolicy AllSigned

# 1. Erstellen Sie ein selbstsigniertes Zertifikat für die Codesignierung
$CHT = @{
  Subject           = 'PS Code Signing'
  Type              = 'CodeSigning' 
  CertStoreLocation = 'Cert:\CurrentUser\My'
}
$Cert = New-SelfSignedCertificate @CHT

# 2. Zeigen Sie das neu erstellte Zertfikat an
Get-ChildItem -Path Cert:\CurrentUser\my -CodeSigningCert | 
  Where-Object {$_.Subjectname.Name -match $CHT.Subject}

# 3. Erstellen Sie ein einfaches Skript
if (!(Test-Path 'C:\foo')) 
   {
      New-Item -Path 'C:\foo' -ItemType Directory
   }

$Script = @"
 # Beispielskript
 'Hello World!'
 Hostname
"@
$Script | Out-File -FilePath c:\foo\signed.ps1
Get-ChildItem -Path C:\foo\signed.ps1

# 4. Signieren Sie das Skript
$SHT = @{
  Certificate = $cert
  FilePath    = 'C:\foo\signed.ps1'
}
Set-AuthenticodeSignature @SHT

# 5. Sehen sie sich das Skript an, nachdem es signiert wurde
Get-ChildItem -Path C:\foo\signed.ps1

# 6. Testen Sie die Signatur
Get-AuthenticodeSignature -FilePath C:\foo\signed.ps1 |
  Format-List

# 7. Stellen Sie sicher, dass das Zertifikat vertrauenswürdig ist
# Beachten Sie das häßliche Konstrukt bein Öffnen des Speichers 
$DestStoreName  = 'Root'
$DestStoreScope = 'CurrentUser'
$Type   = 'System.Security.Cryptography.X509Certificates.X509Store'
$MHT = @{
  TypeName = $Type  
  ArgumentList  = ($DestStoreName, $DestStoreScope)
}
$DestStore = New-Object  @MHT
$DestStore.Open(
  [System.Security.Cryptography.X509Certificates.OpenFlags]::
    ReadWrite)
$DestStore.Add($cert)
$DestStore.Close()

# 8. Siginieren Sie das Srkipt erneut mit einem vertrauenswürdigen Zertifikat
Set-AuthenticodeSignature @SHT  | Out-Null

# 9. Prüfen Sie das Zertifikat
Get-AuthenticodeSignature -FilePath C:\foo\signed.ps1 | 
  Format-List

# Rückgängig

Gci cert:\ -recurse | where subject -match 'Reskit Code Signing' | RI -Force
ri C:\foo\signed.ps1

Set-ExecutionPolicy Unrestricted

