# PS 1.5 v1.0 - Executionpolicies und eine Umgebung f�r die Codesignierung einrichten
# Auf CLient ausf�hren 

# Teil 1: ExecutionPolicies
#
# ExecutionPolicies legen fest, wann ein Script ausgef�hrt werden darf:
#     Unrestricted   -  Skripte werden ausgef�hrt. Bei Skripten 
#                       nicht vertrauensw�rdiger Quellen erfolgt eine Abfrage
#     RemoteSigned   -  Alle Skripte fremder Quellen m�ssen digital von einem vertrauensw�rdigen 
#                       Herausgeber signiert sein. Lokale Skripte werden ausgef�hrt
#     AllSigned      -  Jedes Skript muss von einem vertrauensw�rdigen Herausgeber signiert sein
#     restricted     -  Standardwert; es werden keine Skripte ausgef�hrt. 
#                       Die PowerShell kann nur interaktiv verwendet werden

Set-ExecutionPolicy AllSigned

# 1. Erstellen Sie ein selbstsigniertes Zertifikat f�r die Codesignierung
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

# 7. Stellen Sie sicher, dass das Zertifikat vertrauensw�rdig ist
# Beachten Sie das h��liche Konstrukt bein �ffnen des Speichers 
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

# 8. Siginieren Sie das Srkipt erneut mit einem vertrauensw�rdigen Zertifikat
Set-AuthenticodeSignature @SHT  | Out-Null

# 9. Pr�fen Sie das Zertifikat
Get-AuthenticodeSignature -FilePath C:\foo\signed.ps1 | 
  Format-List

# R�ckg�ngig

Gci cert:\ -recurse | where subject -match 'Reskit Code Signing' | RI -Force
ri C:\foo\signed.ps1

Set-ExecutionPolicy Unrestricted

