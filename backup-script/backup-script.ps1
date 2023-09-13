# 
# BACKUPSCRIPT
# 
# Generated on: 2023-05-27
# last edit on: 2023-08-07
#


# Initialisiere das Array $BackupFolders als leeres Array
$global:BackupFolders   = @()

$backup = [ordered]@{
    Bitwarden       = $False
    Draytek         = $False
    Portainer       = $False
    Unifi           = $False
    Heimdal         = $False
    Diskstation     = $False
    GitHub          = $False
    SSH             = $False
    Cura            = $False
    PiHole          = $False
    Homeassistant   = $False
    Wireguard       = $False
    Skripte         = $False
    Grafana         = $False
}

function Set-Password {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MinimumLength = 8,                  # Minimale Länge des Passworts
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

        # Wenn das Passwort mindestens eine Großbuchstabe, eine Kleinbuchstabe und eine Ziffer enthält
        if (($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]") -and ($password -cmatch "[0-9]")) {

            # Anzahl der Großbuchstaben, Kleinbuchstaben und Ziffern im Passwort zählen
            $countUpperCase = ($password -replace "[^A-Z]").Length
            $countLowerCase = ($password -replace "[^a-z]").Length
            $countDigit = ($password -replace "[^\d]").Length

            # Wenn das Passwort die Mindestanforderungen erfüllt
            if (($countUpperCase -ge $MinimumUpperCase) -and ($countLowerCase -ge $MinimumLowerCase) -and ($countDigit -ge $MinimumDigit)) {
                $securePasswordConfirm = Read-Host "Geben Sie das Passwort zur Bestätigung ein" -AsSecureString
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))

                # Wenn das bestätigte Passwort nicht mit dem eingegebenen Passwort übereinstimmt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
                if ($password -ne $passwordConfirm) {
                    Write-Error "Die Passwörter stimmen nicht überein."
                    continue
                }

                # Wenn alle Anforderungen erfüllt sind, das Passwort zurückgeben
                return $securePassword
            }
        }

        # Wenn das Passwort nicht die Mindestanforderungen erfüllt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
        Write-Error "Das Passwort erfüllt nicht die Anforderungen an Komplexität. Es muss mindestens $MinimumUpperCase Großbuchstaben, $MinimumLowerCase Kleinbuchstaben und $MinimumDigit Ziffern enthalten."
    } while ($true)
}

function LogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$logMessage,
        [Parameter(Mandatory = $true)]
        [string]$backupname,
        [Parameter(Mandatory = $true)]
        [string]$archiv
    )

    # Assemblys laden
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 8.0.33\MySql.Data.dll"

    $envFile = "$env:USERPROFILE\Documents\GitHub\backup-script\config.env"
    $envData = Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if (-not [string]::IsNullOrEmpty($line) -and -not $line.StartsWith("#")) {
            $parts = $line -split "=", 2
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            Set-Variable -Name $key -Value $value
        }
    }

    $connectionString = "Server=$SERVER_IP;Port=$SERVER_PORT;Database=$DATABASE;Uid=$USERNAME;Pwd=$PASSWORD"

    try {
        $connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
        $connection.Open()

        $query = "CREATE TABLE IF NOT EXISTS backups (id INT AUTO_INCREMENT PRIMARY KEY, backupname TEXT, archiv TEXT, timestamp DATETIME, message TEXT)"
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $connection)
        $command.ExecuteNonQuery()

        $query = "INSERT INTO backups (backupname, archiv, timestamp, message ) VALUES (@backupname, @archiv, @timestamp, @message)"
        $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $connection)

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $command.Parameters.AddWithValue("@timestamp", $timestamp)
        $command.Parameters.AddWithValue("@message", $logMessage)
        $command.Parameters.AddWithValue("@backupname", $backupname)
        $command.Parameters.AddWithValue("@archiv", $archiv)

        $command.ExecuteNonQuery()

        Write-Output "Logeintrag erfolgreich geschrieben: $logMessage"
    }
    catch {
        Write-Output "Fehler beim Schreiben des Logeintrags: $_"
    }
    finally {
        $connection.Close()
    }
}

function Backup-Folder {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$SourceFolder,
        
        [Parameter(Mandatory = $false)]
        [string]$BackupName,
        
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Password
    )

    # Wenn kein Backup-Name angegeben wurde, wird der ursprüngliche Ordnername verwendet.
    if (!$BackupName) {
        $BackupName = (Split-Path $SourceFolder -Leaf)
    }

    # Erstellt den Pfad, in dem das Backup gespeichert wird, wenn er noch nicht existiert.
    $BackupPath = "$env:USERPROFILE\OneDrive\06 - Backups\$BackupName"
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    # Erstellt den Namen und Pfad des 7zip-Archivs, das erstellt werden soll.
    $Date = (Get-Date).ToString("yyyy-MM")
    $ArchiveName = "$Date-$BackupName-Backup.7z"
    $ArchivePath = Join-Path $BackupPath $ArchiveName

    # Parameter für das Compress-7Zip-Cmdlet.
    $ZipArgs = @{
        Path = $SourceFolder
        CompressionLevel = 'Ultra'
        CompressionMethod = 'LZMA2'
        SecurePassword = $Password
        ArchiveFileName = $ArchivePath
        EncryptFilenames = $true
    }

    # Speichert die aktuelle Zeit vor der Komprimierung des Ordners.
    $StartTime = Get-Date

    # Ausgabe, welche Datei gerade komprimiert wird.
    Write-Output "Komprimiere: $BackupName"

    # Komprimiert den Ordner mit 7zip.
    Compress-7Zip @ZipArgs > $null

    # Speichert die Zeit nach der Komprimierung des Ordners und berechnet die Dauer.
    $EndTime = Get-Date
    $Duration = New-TimeSpan -Start $StartTime -End $EndTime

    # Entfernt alte Backups, wenn es mehr als 12 Backups gibt.
    $BackupList = Get-ChildItem $BackupPath -Filter *.7z
    if ($BackupList.Count -gt 12) {
        $OldestBackup = $BackupList | Sort-Object CreationTime | Select-Object -First 1
        Remove-Item $OldestBackup.FullName
    }

    # Berechnet die Dauer des Backup-Vorgangs und Ausgabe, dass das Backup erfolgreich erstellt wurde.
    $DurationString = "{0:F3}" -f $Duration.TotalSeconds
    LogEntry -logMessage "Backup erstellt: $BackupName ($ArchiveName) in $DurationString Sekunden" -backupname $BackupName -archiv $ArchiveName
    Write-Output ""
}

function Move-BackupFiles {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$BackupName,
        [string]$SearchPattern,
        [string]$SearchFolder = "$env:USERPROFILE\Downloads",
        [string]$TargetFolder = "$env:USERPROFILE\Downloads",
        [switch]$Copy,
        [switch]$Move = !$Copy,
        [switch]$Recurse,
        [switch]$NoRename
    )

    # Durchsuche das Quellverzeichnis nach passenden Dateien
    $items = Get-ChildItem -Path $SearchFolder -File | Where-Object { $_.Name -match $SearchPattern }

    # Wenn mindestens eine passende Datei oder ein passendes Verzeichnis gefunden wurde
    if ($items) {
        # Erstelle das Zielverzeichnis, falls es nicht bereits vorhanden ist
        if (!(Test-Path $TargetFolder\$BackupName)) {
            New-Item -ItemType Directory -Path $TargetFolder\$BackupName | Out-Null
        }

        # Kopieren/Verschieben alle passenden Dateien/Verzeichnisse in das Zielverzeichnis und benenne sie um
        $date = Get-Date -Format "yyyy-MM"
        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($SearchFolder.Length)

            if ($item.PSIsContainer) {
                # Wenn es sich um ein Verzeichnis handelt, erstelle es im Zielverzeichnis
                $destinationDirectory = Join-Path $TargetFolder\$BackupName $relativePath
                New-Item -ItemType Directory -Path $destinationDirectory | Out-Null

                # Kopiere/verschiebe den gesamten Inhalt des Verzeichnisses, wenn die -Recurse-Option angegeben wurde
                if ($Recurse) {
                    $destinationSubdirectory = Join-Path $TargetFolder\$BackupName $relativePath.Substring(1)
                    Copy-Item $item.FullName\* $destinationSubdirectory -Recurse -Force
                }

            } else {
                # Wenn es sich um eine Datei handelt, kopiere/verschiebe sie ins Zielverzeichnis und benenne sie um
                $newName = $item.Name

                if (!$NoRename) {
                    if ($item.Extension -eq '.gz' -and $item.Name.Contains('.tar')) {
                        $newName = '{0}-{1}-Backup.tar.gz' -f $date, $BackupName
                    } else {
                        $newName = '{0}-{1}-Backup{2}' -f $date, $BackupName, $item.Extension
                    }
                }

                $destinationFile = Join-Path $TargetFolder\$BackupName $newName

                if ($Copy) {
                    Copy-Item $item.FullName $destinationFile
                } elseif ($Move) {
                    Move-Item $item.FullName $destinationFile
                }
            }
        }

        # Hinzufügen des neuen Eintrags zu $BackupFolders
        $global:BackupFolders += [PSCustomObject] @{
            Path = "$TargetFolder\$BackupName"
            BackupName = $BackupName
        }
        $backup[$BackupName] = $True
    } else {
        # Wenn keine passende Datei oder Verzeichnis gefunden wurde, gib eine Warnung aus
        Write-Warning "Keine Dateien oder Verzeichnisse mit dem Suchmuster '$SearchPattern' im Verzeichnis '$SearchFolder' gefunden. Backup '$BackupName' wurde nicht erstellt."
    }
}
function Copy-RemoteData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$serverName, # Name des Remote-Servers

        [Parameter(Mandatory=$true, Position=1)]
        [string]$remotePath, # Pfad auf dem Remote-Server

        [Parameter(Mandatory=$true, Position=2)]
        [string]$name, # Name des Ordners, in dem die Daten gespeichert werden

        [Parameter(Position=3)]
        [string]$destinationPath = "$env:USERPROFILE\Downloads" # Standardzielverzeichnis auf dem lokalen Computer
    )

    # Kombinieren von Servernamen und Pfad auf dem Remote-Server zu einem SCP-kompatiblen Pfad
    $sourcePath = "$serverName`:$remotePath"

    # Verzeichnis für die Dateien erstellen
    $directoryPath = Join-Path $destinationPath $name
    New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

    # Ausführen des scp-Befehls, um die Daten in das Verzeichnis zu kopieren
    scp $sourcePath $directoryPath > $null

    # Hinzufügen des Verzeichnisses zur globalen Sicherungsliste
    $global:BackupFolders += [PSCustomObject] @{
        Path = $directoryPath
        BackupName = $name
    }
    $backup[$name] = $True
}

function Ausgabe {
    param (
        [string]$Name,
        [int]$Index
    )

    $columnWidth = 25
    $indexFormatted = "{0,2}. " -f $Index
    $nameFormatted = "{0,-$columnWidth}" -f $Name

    if ($backup[$Name]) {
        Write-Host ("{0}{1}" -f $indexFormatted, $nameFormatted) -ForegroundColor Green
    } else {
        Write-Host ("{0}{1}" -f $indexFormatted, $nameFormatted)
    }
}

# Hauptmenü
function ShowMainMenu {
    Clear-Host
    Write-Host "##################################"
    Write-Host "#          Backup-Skript         #"
    Write-Host "##################################"
    Write-Host ""

    $index = 1
    foreach ($tool in $backup.Keys) {
        Ausgabe -Name $tool -Index $index
        $index++
    }

    Write-Host ""
    Write-Host -ForegroundColor Yellow "x - Backups erstellen"
    Write-Host -ForegroundColor Red "0. Beenden"
    Write-Host

    # Eingabe der Benutzerwahl
    $choice = Read-Host "Deine Auswahl"

    # Verarbeitung der Benutzerwahl
    switch ($choice) {
        "1" {
            bw login 
            bw export --format json --output (Join-Path $env:USERPROFILE "Downloads\")
            Write-Host ""
            bw logout | Out-Null

            Move-BackupFiles -BackupName "Bitwarden" -SearchPattern 'bitwarden_export_(\d{14}).json'
        }

        "2" {
            Move-BackupFiles -BackupName "Draytek" -SearchPattern '^V165_\d{8}_Modem_424_STD\.cfg$'
        }

        "3" {
            Move-BackupFiles -BackupName "Portainer" -SearchPattern 'portainer-backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.tar\.gz'
        }

        "4" {
            Move-BackupFiles -BackupName "Unifi" -SearchPattern '^.*(unifi|network).*(\.unf|\.unifi)$'
        }

        "5" {
            Move-BackupFiles -BackupName "Heimdal" -SearchPattern 'heimdallexport.json'
        }

        "6" {
            Move-BackupFiles -BackupName "Diskstation" -SearchPattern 'Diskstation_[0-9]{8}\.dss'
        }

        "7" {
            Copy-Item -Path "$env:USERPROFILE\Documents\GitHub\" -Destination "$env:USERPROFILE\Downloads\" -Recurse
            $global:BackupFolders += [PSCustomObject] @{
                Path = "$env:USERPROFILE\Downloads\GitHub"
                BackupName = "GitHub"
            }
            $backup["GitHub"] = $True
        }

        "8" {
            Move-BackupFiles -BackupName "SSH" -SearchFolder $env:USERPROFILE\.ssh -Copy -Recurse -NoRename
        }

        "9" {
            $SearchFolder = Get-ChildItem $env:APPDATA\cura\ -Directory | Sort-Object @{ Expression = { [regex]::Replace($_.Name, '.*(\d+(\.\d+)*)$', '$1') } } -Descending
            $SelectedFolder = $SearchFolder | Select-Object -First 1
            $SearchFolder = Join-Path $SelectedFolder.FullName "quality_changes"
            $filePath = Join-Path $SearchFolder "WICHTIG - LESEN!.txt"
            Set-Content -Path $filePath  -Value "Backup aus $SearchFolder"
            Move-BackupFiles -BackupName "Cura" -SearchPattern '.*\.(txt|cfg)$' -SearchFolder $SearchFolder -Copy -NoRename
        }

        "10" {
            Copy-RemoteData -serverName "Docker-Pi-1" -remotePath "/home/erik/backup/*-pihole-backup.tar.gz" -name "PiHole"
        }

        "11" {
            Copy-RemoteData -serverName "Homeassistant" -remotePath "/backup/*.tar" -name "Homeassistant"
        }

        "12" {
            Copy-RemoteData -serverName "Docker-Pi-1" -remotePath "/home/erik/pivpnbackup/*-pivpnwgbackup.tgz" -name "Wireguard"
        }

        "13" {
            Copy-RemoteData -serverName "Docker-Pi-1" -remotePath "/home/erik/skripts/*" -name "Skripte"
        }

        "14" {
            $envFile = "$env:USERPROFILE\Documents\GitHub\backup-script\config.env"
            $envData = Get-Content $envFile | ForEach-Object {
                $line = $_.Trim()
                if (-not [string]::IsNullOrEmpty($line) -and -not $line.StartsWith("#")) {
                    $parts = $line -split "=", 2
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim()
                    Set-Variable -Name $key -Value $value
                }
            }

            $exportBasePath = "$env:USERPROFILE\Downloads\Grafana"

            # Erstelle das Ausgabeverzeichnis, wenn es nicht existiert
            if (-not (Test-Path -Path $exportBasePath)) {
                New-Item -Path $exportBasePath -ItemType Directory | Out-Null
            }

            $dashboardsOutputPath = Join-Path -Path $exportBasePath -ChildPath "Dashboards"
            $datasourcesOutputPath = Join-Path -Path $exportBasePath -ChildPath "Datasources"

            # Erstelle die Unterordner, wenn sie nicht existieren
            if (-not (Test-Path -Path $dashboardsOutputPath)) {
                New-Item -Path $dashboardsOutputPath -ItemType Directory | Out-Null
            }

            if (-not (Test-Path -Path $datasourcesOutputPath)) {
                New-Item -Path $datasourcesOutputPath -ItemType Directory | Out-Null
            }

            # Hole die Liste der Dashboards
            $headers = @{
                Authorization = "Bearer $apiToken"
            }
            $dashboardsResponse = Invoke-RestMethod -Uri "$grafanaUrl/api/search?type=dash-db" -Headers $headers

            # Durchlaufe die Dashboards und exportiere sie
            foreach ($dashboard in $dashboardsResponse) {
                $dashboardUid = $dashboard.uid
                $dashboardName = $dashboard.title
                $dashboardResponse = Invoke-RestMethod -Uri "$grafanaUrl/api/dashboards/uid/$dashboardUid" -Headers $headers
                $dashboardJson = $dashboardResponse.dashboard | ConvertTo-Json -Depth 10

                $outputFilePath = Join-Path -Path $dashboardsOutputPath -ChildPath "dashboard_$dashboardName.json"
                $dashboardJson | Set-Content -Path $outputFilePath

                # Write-Host "Dashboard '$dashboardName' exportiert nach: $outputFilePath"
            }

            # Hole die Liste der Datenquellen
            $datasourcesResponse = Invoke-RestMethod -Uri "$grafanaUrl/api/datasources" -Headers $headers

            # Durchlaufe die Datenquellen und exportiere sie
            foreach ($datasource in $datasourcesResponse) {
                $datasourceName = $datasource.name
                $datasourceJson = $datasource | ConvertTo-Json -Depth 10

                $outputFilePath = Join-Path -Path $datasourcesOutputPath -ChildPath "datasource_$datasourceName.json"
                $datasourceJson | Set-Content -Path $outputFilePath

                # Write-Host "Datenquelle '$datasourceName' exportiert nach: $outputFilePath"
            }

            $global:BackupFolders += [PSCustomObject] @{
                Path = "$env:USERPROFILE\Downloads\Grafana"
                BackupName = "Grafana"
            }
            $backup["Grafana"] = $True
        }

        "0" {
            return
        }

        "x" {
            $securePassword = Set-Password
            foreach ($Folder in ($BackupFolders | Sort-Object -Unique -Property BackupName)) {
                if (Backup-Folder -SourceFolder $Folder.Path -BackupName $Folder.BackupName -Password $securePassword) {
                    Remove-Item $Folder.Path -Recurse -Force
                    $backup[$Folder.BackupName] = $False
                }
            }
            $global:BackupFolders   = @()
        }

        default {
            Write-Host "Ungültige Auswahl. Bitte versuche es erneut."
        }
    }

    # Nachdem die ausgewählte Aktion abgeschlossen ist, zurück zum Hauptmenü gehen
    Write-Host
    Write-Host "Drücke eine beliebige Taste, um fortzufahren..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    ShowMainMenu
}

# Hauptmenü anzeigen
ShowMainMenu

