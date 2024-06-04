##########################################
#  Install-Module -Name 7Zip4Powershell  #
##########################################

$server        = "bitwarden.selfhosted.de"
$backupFolder  = 'C:\Users\erik\OneDrive\06 - Backups\Bitwarden'
$user          = @("user-1l@outlook.de","user-2@outlook.de")
$extension     = "json"

function Set-Password {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MinimumLength = 8,                  # Minimale Laenge des Passworts
        [Parameter()]
        [int]$MinimumUpperCase = 1,               # Minimale Anzahl an Großbuchstaben
        [Parameter()]
        [int]$MinimumLowerCase = 1,               # Minimale Anzahl an Kleinbuchstaben
        [Parameter()]
        [int]$MinimumDigit = 1                    # Minimale Anzahl an Ziffern
    )

    # Passwort abfragen und in SecureString umwandeln
    do {
        $securePassword = Read-Host "Geben Sie ein sicheres Passwort ein" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

        if ($password.Length -lt $MinimumLength) {  # Wenn das Passwort zu kurz ist, Fehlermeldung ausgeben und Schleife erneut durchlaufen
            Write-Error "Das Passwort muss mindestens $MinimumLength Zeichen lang sein."
            continue
        }

        # Wenn das Passwort mindestens eine Großbuchstabe, eine Kleinbuchstabe und eine Ziffer enthaelt
        if (($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]") -and ($password -cmatch "[0-9]")) {

            # Anzahl der Großbuchstaben, Kleinbuchstaben und Ziffern im Passwort zaehlen
            $countUpperCase = ($password -replace "[^A-Z]").Length
            $countLowerCase = ($password -replace "[^a-z]").Length
            $countDigit = ($password -replace "[^\d]").Length

            # Wenn das Passwort die Mindestanforderungen erfuellt
            if (($countUpperCase -ge $MinimumUpperCase) -and ($countLowerCase -ge $MinimumLowerCase) -and ($countDigit -ge $MinimumDigit)) {
                $securePasswordConfirm = Read-Host "Geben Sie das Passwort zur Bestaetigung ein" -AsSecureString
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))

                # Wenn das bestaetigte Passwort nicht mit dem eingegebenen Passwort uebereinstimmt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
                if ($password -ne $passwordConfirm) {
                    Write-Error "Die Passwörter stimmen nicht ueberein."
                    continue
                }

                # Wenn alle Anforderungen erfuellt sind, das Passwort zurueckgeben
                return $securePassword
            }
        }

        # Wenn das Passwort nicht die Mindestanforderungen erfuellt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
        Write-Error "Das Passwort erfuellt nicht die Anforderungen an Komplexitaet. Es muss mindestens $MinimumUpperCase Großbuchstaben, $MinimumLowerCase Kleinbuchstaben und $MinimumDigit Ziffern enthalten."
    } while ($true)
}

# Serverkonfiguration
if ($server) {
    Write-Host "`nVerwende selbstgehosteten Bitwarden-Tresor ($server)"
    bw config server $server | Out-Null
} else {
    Write-Host "`nVerwende Standard-Bitwarden-Tresor (https://vault.bitwarden.com)"
    bw config server https://vault.bitwarden.com | Out-Null
}
Write-Host "`n"

foreach ($u in $user) {
    Write-Host "Sichere Bitwarden-Daten fuer Benutzer: $u"

    # Masterpasswort abfragen und anmelden
    $masterPass = Read-Host -Prompt "Bitte geben Sie Ihr Masterpasswort fuer $u ein" -AsSecureString 
    $masterPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPass))

    $loggedIn = $false

    while (-not $loggedIn) {
        try {
            $key = bw login $u $masterPass --raw
            if ($key) {
                Write-Host "`nAnmeldung erfolgreich." -ForegroundColor Green
                $env:BW_SESSION = $key
                $loggedIn = $true
            } else {
                throw "UngueltigeAnmeldeinformationen"
            }
        } catch {
            $masterPass = Read-Host -Prompt "`nFalsches Passwort. Bitte geben Sie Ihr Masterpasswort erneut ein" -AsSecureString
            $masterPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPass))
        }
    }

    # Backup-Dateinamen erstellen
    $timestamp      = Get-Date -Format "yyyy-MM-dd"
    $backupFile     = "$timestamp-$u.$extension"
    $userBackupFolder = Join-Path -Path $backupFolder -ChildPath $u
    $backupDateFolder = Join-Path -Path $userBackupFolder -ChildPath $timestamp
    $attachmentFolder = Join-Path -Path $backupDateFolder -ChildPath "Anlagen"

    # Bitwarden-Tresor synchronisieren und exportieren
    Write-Host "Synchronisiere Bitwarden-Tresor..."
    bw sync | Out-Null
    Write-Host "Exportiere Bitwarden-Tresor..."
    if (-not (Test-Path -Path $backupDateFolder)) {
        New-Item -Path $backupDateFolder -ItemType Directory | Out-Null
    }
    bw export --output "$backupDateFolder\$backupFile" --format $extension $masterPass | Out-Null
    Write-Host "Bitwarden-Tresor erfolgreich exportiert." -ForegroundColor Green

    # Anhaenge sichern
    Write-Host "Sichere Anhaenge..."
    if (-not (Test-Path -Path $attachmentFolder)) {
        New-Item -Path $attachmentFolder -ItemType Directory | Out-Null
    }
    $vault = bw list items | ConvertFrom-Json
    foreach ($item in $vault){
        if($item.PSobject.Properties.Name -contains "Attachments"){
            foreach ($attachment in $item.attachments){
                $exportName = if ($item.Login.Username) { "$($item.name) - $($item.Login.Username) - $($attachment.fileName)" } else { "$($item.name) - $($attachment.fileName)" }
                bw get attachment $attachment.id --itemid $item.id --output "$attachmentFolder\$exportName" | Out-Null
                Write-Host "Anhang gesichert: $exportName"
            }
        }
    }

    Write-Host "`nAlle Anhaenge erfolgreich gesichert fuer Benutzer: $u" -ForegroundColor Green

    # Abmelden
    Write-Host "`nMelde vom Tresor ab..."
    bw logout | Out-Null
    Write-Host "Sie wurden erfolgreich vom Tresor abgemeldet." -ForegroundColor Green

    Write-Host "`nBackup-Datei" -ForegroundColor Green
    # Install-Module -Name 7zip4PowerShell -Verbose
    $SecureString = Set-Password
    
    Compress-7zip -Path $backupDateFolder `
            -OutputPath "$userBackupFolder" `
            -ArchiveFileName "$timestamp-bitwarden-backup.7z" `
            -CompressionLevel "Ultra" `
            -CompressionMethod "Lzma2" `
            -EncryptFilenames `
            -SecurePassword $SecureString
    
    # Verzeichnis löschen
    Remove-Item -Path $backupDateFolder -Recurse -Force
}

Pause
Exit
