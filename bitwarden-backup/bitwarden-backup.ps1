# Bitwarden Passwort-Manager Backup-Skript für zwei Konten

# Konfigurationen
$server        = "bitwarden.selfhosted.de"
$backupFolder  = 'C:\Users\............'
$user          = @("user-1","user-2")
$extension     = "json"

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
    Write-Host "Sichere Bitwarden-Daten für Benutzer: $u"

    # Masterpasswort abfragen und anmelden
    $masterPass = Read-Host -Prompt "Bitte geben Sie Ihr Masterpasswort für $u ein" -AsSecureString -Encoding UTF8
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
                throw "UngültigeAnmeldeinformationen"
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

    # Anhänge sichern
    Write-Host "Sichere Anhänge..."
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

    Write-Host "`nAlle Anhänge erfolgreich gesichert für Benutzer: $u" -ForegroundColor Green

    # Abmelden
    Write-Host "`nMelde vom Tresor ab..."
    bw logout | Out-Null
    Write-Host "Sie wurden erfolgreich vom Tresor abgemeldet." -ForegroundColor Green
}

Pause
Exit
