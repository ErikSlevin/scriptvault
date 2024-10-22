# Define default values for server, backup folder, and emails
# Definiere Standardwerte für Server, Backup-Ordner und E-Mail-Adressen
$defaultServer = "selfhosted-bitwarden.server.com"
$defaultBackupFolder = "C:\my-backup-folder\Bitwarden"
$defaultEmails = @("bitwarden-user-1@gmx.de", "bitwarden-user-2@outlook.de", "bitwarden-user-3@gmail.de")

# Paths to configuration file and function to load configuration
# Pfade zur Konfigurationsdatei und Funktion zum Laden der Konfiguration
$configFilePath = "C:\Users\erikw\Documents\GitHub\scriptvault\bitwarden-backup\config.ini"

function Load-Config($path) {
    # Check if configuration file exists
    # Überprüfe, ob die Konfigurationsdatei existiert
    if (Test-Path $path) {
        try {
            # Read the content of the configuration file
            # Lese den Inhalt der Konfigurationsdatei
            $iniContent = Get-Content -Path $path
            $config = @{}
            $section = ""
            # Iterate through each line of the configuration file
            # Iteriere durch jede Zeile der Konfigurationsdatei
            foreach ($line in $iniContent) {
                $line = $line.Trim()
                # Check if the line contains a section header
                # Überprüfe, ob die Zeile eine Sektionsüberschrift enthält
                if ($line -match "^\[(.+?)\]$") {
                    $section = $matches[1]
                    $config[$section] = @{}
                } 
                # Check if the line contains a key-value pair
                # Überprüfe, ob die Zeile eine Schlüssel-Wert-Paar enthält
                elseif ($line -match "^([^=]+)=(.+)$") {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    # Add the key-value pair to the appropriate section in the configuration
                    # Füge das Schlüssel-Wert-Paar zur entsprechenden Sektion in der Konfiguration hinzu
                    if ($section) {
                        $config[$section][$key] = $value
                    }
                }
            }
            return $config
        } 
        # Handle errors when loading the configuration file
        # Behandele Fehler beim Laden der Konfigurationsdatei
        catch {
            Write-Error "Error loading configuration file: $_"
            return $null
        }
    } 
    # Use default values if the configuration file is not found
    # Verwende Standardwerte, wenn die Konfigurationsdatei nicht gefunden wird
    else {
        Write-Host "Configuration file not found, default values will be used."
        return $null
    }
}

# Load the configuration from the specified file
# Lade die Konfiguration aus der angegebenen Datei
$config = Load-Config $configFilePath

# Check if the configuration was loaded successfully and set server, backup folder, and emails accordingly
# Überprüfe, ob die Konfiguration erfolgreich geladen wurde und setze entsprechend Server, Backup-Ordner und E-Mail-Adressen
if ($config -ne $null) {
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

# Function for setting password with length, uppercase, lowercase, and digit requirements
# Funktion zur Passwortfestlegung mit Anforderungen an Länge, Groß-/Kleinbuchstaben und Zahlen
function Set-Password {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MinimumLength = 8,
        [Parameter()]
        [int]$MinimumUpperCase = 1,
        [Parameter()]
        [int]$MinimumLowerCase = 1,
        [Parameter()]
        [int]$MinimumDigit = 1
    )

    do {
        # Prompt user to enter a secure password
        # Benutzer wird aufgefordert, ein sicheres Passwort einzugeben
        $securePassword = Read-Host "Enter a secure password" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

        # Check if the entered password meets the requirements
        # Überprüfe, ob das eingegebene Passwort die Anforderungen erfüllt
        if ($password.Length -lt $MinimumLength) {
            Write-Error "Password must be at least $MinimumLength characters long."
            continue
        }

        if (($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]") -and ($password -cmatch "[0-9]")) {
            $countUpperCase = ($password -replace "[^A-Z]").Length
            $countLowerCase = ($password -replace "[^a-z]").Length
            $countDigit = ($password -replace "[^\d]").Length

            if (($countUpperCase -ge $MinimumUpperCase) -and ($countLowerCase -ge $MinimumLowerCase) -and ($countDigit -ge $MinimumDigit)) {
                # Prompt user to enter password for confirmation
                # Benutzer wird aufgefordert, das Passwort zur Bestätigung einzugeben
                $securePasswordConfirm = Read-Host "Enter the password for confirmation" -AsSecureString
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))

                if ($password -ne $passwordConfirm) {
                    Write-Error "Passwords do not match."
                    continue
                }

                return $securePassword
            }
        }

        Write-Error "Password does not meet complexity requirements. It must contain at least $MinimumUpperCase uppercase letters, $MinimumLowerCase lowercase letters, and $MinimumDigit digits."
    } while ($true)
}

# Set the server for the Bitwarden vault based on the configuration or default value
# Setze den Server für den Bitwarden-Tresor basierend auf der Konfiguration oder Standardwert
if ($server) {
    Write-Host "`nUsing self-hosted Bitwarden vault ($server)"
    bw config server $server | Out-Null
} else {
    Write-Host "`nUsing default Bitwarden vault (https://vault.bitwarden.com)"
    bw config server https://vault.bitwarden.com | Out-Null
}
Write-Host "`n"

# Secure data for each user in the list of emails
# Sichere Daten für jeden Benutzer in der Liste der E-Mail-Adressen
foreach ($user in $emails) {
    Write-Host "Securing Bitwarden data for user: $user"
    
    # Prompt user to enter the master password
    # Benutzer wird aufgefordert, das Masterpasswort einzugeben
    $masterPass = Read-Host -Prompt "Please enter your master password for $user" -AsSecureString 
    $masterPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPass))

    $loggedIn = $false

    # Log in to the Bitwarden vault with the entered credentials
    # Anmeldung am Bitwarden-Tresor mit den eingegebenen Anmeldeinformationen
    while (-not $loggedIn) {
        try {
            $key = bw login $user $masterPass --raw
            if ($key) {
                Write-Host "`nLogin successful." -ForegroundColor Green
                $env:BW_SESSION = $key
                $loggedIn = $true
            } else {
                throw "InvalidCredentials"
            }
        } catch {
            # Prompt user to enter the password again if it's incorrect
            # Benutzer wird aufgefordert, das Passwort erneut einzugeben, wenn es falsch ist
            $masterPass = Read-Host -Prompt "`nIncorrect password. Please enter your master password again" -AsSecureString
            $masterPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($masterPass))
        }
    }

    # Create filename and folder path for backup
    # Erstelle den Dateinamen und Ordnerpfad für das Backup
    $timestamp      = Get-Date -Format "yyyy-MM-dd"
    $backupFile     = "$timestamp-$user.json"
    $userBackupFolder = Join-Path -Path $backupFolder -ChildPath $user
    $backupDateFolder = Join-Path -Path $userBackupFolder -ChildPath $timestamp
    $attachmentFolder = Join-Path -Path $backupDateFolder -ChildPath "Attachments"

    # Synchronize Bitwarden vault and export data
    # Synchronisiere den Bitwarden-Tresor und exportiere die Daten
    Write-Host "Synchronizing Bitwarden vault..."
    bw sync | Out-Null
    Write-Host "Exporting Bitwarden vault..."

    # Create backup folder if it doesn't exist
    # Erstelle den Backup-Ordner, wenn er nicht existiert
    if (-not (Test-Path -Path $backupDateFolder)) {
        New-Item -Path $backupDateFolder -ItemType Directory | Out-Null
    }

    # Export Bitwarden vault as JSON file
    # Exportiere den Bitwarden-Tresor als JSON-Datei
    bw export --output "$backupDateFolder\$backupFile" --format "json" $masterPass | Out-Null
    Write-Host "Bitwarden vault exported successfully." -ForegroundColor Green

    # Secure attachments, if any
    # Sichere Anhänge, falls vorhanden
    Write-Host "Securing attachments..."
    if (-not (Test-Path -Path $attachmentFolder)) {
        New-Item -Path $attachmentFolder -ItemType Directory | Out-Null
    }
    $vault = bw list items | ConvertFrom-Json
    foreach ($item in $vault){
        if($item.PSobject.Properties.Name -contains "Attachments"){
            foreach ($attachment in $item.attachments){
                $exportName = if ($item.Login.Username) { "$($item.name) - $($attachment.fileName)" } else { "$($item.name) - $($attachment.fileName)" }
                bw get attachment $attachment.id --itemid $item.id --output "$attachmentFolder\$exportName" | Out-Null
                Write-Host "Attachment secured: $exportName"
            }
        }
    }

    Write-Host "`nAll attachments secured successfully for user: $user" -ForegroundColor Green

    # Log out from Bitwarden vault
    # Abmeldung vom Bitwarden-Tresor
    Write-Host "`nLogging out from vault..."
    bw logout | Out-Null
    Write-Host "Successfully logged out from vault." -ForegroundColor Green

    # Encrypt the backup and delete the temporary folder
    # Verschlüssele das Backup und lösche den temporären Ordner
    Write-Host "`nBackup File" -ForegroundColor Green
    $SecureString = Set-Password
    
    Compress-7zip -Path $backupDateFolder `
            -OutputPath "$userBackupFolder" `
            -ArchiveFileName "$timestamp-bitwarden-backup.7z" `
            -CompressionLevel "Ultra" `
            -CompressionMethod "Lzma2" `
            -EncryptFilenames `
            -SecurePassword $SecureString
    
    Remove-Item -Path $backupDateFolder -Recurse -Force
}

Pause
Exit
