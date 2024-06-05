##########################################
#  Install-Module -Name 7Zip4Powershell  #
##########################################

# Standardwerte, die verwendet werden, wenn die Konfigurationsdatei nicht existiert
$defaultServer = "selfhosted-bitwarden.server.com"
$defaultBackupFolder = "C:\my-backup-folder\Bitwarden"
$defaultEmails = @("bitwarden-user-1@gmx.de", "bitwarden-user-2@outlook.de", "bitwarden-user-3@gmail.de")

# Optional
# Pfad zur Konfigurationsdatei Aufbau:
#
# [Secrets]
# server=selfhosted-bitwarden.server.com
# backupFolder=C:\my-backup-folder\Bitwarden
# 
# [Users]
# user=bitwarden-user-1@gmx.de,bitwarden-user-2@outlook.de,bitwarden-user-3@gmail.de
$configFilePath = "C:\Users\erikw\Documents\GitHub\scriptvault\bitwarden-backup\config.ini"

# Funktion zum Laden der Konfigurationsdatei
function Load-Config($path) {
    if (Test-Path $path) {
        try {
            # Konfigurationsdatei einlesen
            $iniContent = Get-Content -Path $path

            # Hashtable zur Speicherung der Konfigurationswerte
            $config = @{}

            # Abschnitt und Schlüssel-Wert-Paare auslesen
            $section = ""
            foreach ($line in $iniContent) {
                $line = $line.Trim()
                if ($line -match "^\[(.+?)\]$") {
                    $section = $matches[1]
                    $config[$section] = @{}
                } elseif ($line -match "^([^=]+)=(.+)$") {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($section) {
                        $config[$section][$key] = $value
                    }
                }
            }
            return $config
        } catch {
            Write-Error "Fehler beim Laden der Konfigurationsdatei: $_"
            return $null
        }
    } else {
        Write-Host "Konfigurationsdatei nicht gefunden, Standardwerte werden verwendet."
        return $null
    }
}

# Konfigurationsdatei laden
$config = Load-Config $configFilePath

# Variablen setzen, abhängig davon, ob die Konfigurationsdatei geladen wurde oder nicht
if ($null -ne $config) {
    if ($config.ContainsKey("Secrets")) {
        $server = $config.Secrets.server
        $backupFolder = $config.Secrets.backupFolder
    } else {
        $server = $defaultServer
        $backupFolder = $defaultBackupFolder
    }

    if ($config.ContainsKey("Users")) {
        $emails = $config.Users.emails -split ","
    } else {
        $emails = $defaultEmails
    }
} else {
    $server = $defaultServer
    $backupFolder = $defaultBackupFolder
    $emails = $defaultEmails
}

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

foreach ($user in $emails) {
    Write-Host "Sichere Bitwarden-Daten fuer Benutzer: $user"
    
    # Masterpasswort abfragen und anmelden
    $masterPass = Read-Host -Prompt "Bitte geben Sie Ihr Masterpasswort fuer $user ein" -AsSecureString 
    $masterPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPass))

    $loggedIn = $false

    while (-not $loggedIn) {
        try {
            $key = bw login $user $masterPass --raw
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
    $backupFile     = "$timestamp-$user.json"
    $userBackupFolder = Join-Path -Path $backupFolder -ChildPath $user
    $backupDateFolder = Join-Path -Path $userBackupFolder -ChildPath $timestamp
    $attachmentFolder = Join-Path -Path $backupDateFolder -ChildPath "Anlagen"

    # Bitwarden-Tresor synchronisieren und exportieren
    Write-Host "Synchronisiere Bitwarden-Tresor..."
    bw sync | Out-Null
    Write-Host "Exportiere Bitwarden-Tresor..."

    if (-not (Test-Path -Path $backupDateFolder)) {
        New-Item -Path $backupDateFolder -ItemType Directory | Out-Null
    }

    bw export --output "$backupDateFolder\$backupFile" --format "json" $masterPass | Out-Null
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
                $exportName = if ($item.Login.Username) { "$($item.name) - $($attachment.fileName)" } else { "$($item.name) - $($attachment.fileName)" }
                bw get attachment $attachment.id --itemid $item.id --output "$attachmentFolder\$exportName" | Out-Null
                Write-Host "Anhang gesichert: $exportName"
            }
        }
    }

    Write-Host "`nAlle Anhaenge erfolgreich gesichert fuer Benutzer: $user" -ForegroundColor Green

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
