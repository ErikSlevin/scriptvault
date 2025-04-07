Clear-Host

# Desktoppfad über .NET ermitteln (nutzerunabhängig, kompatibel)
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Zielordner definieren – hier ein Unterordner "Gewuerze" auf dem Desktop
$folderPath = Join-Path -Path $desktopPath -ChildPath "Gewuerze"

# Optional: Ausgabe zur Kontrolle
Write-Host "Überwachter Ordner: $folderPath"

# Funktion zum Überprüfen, ob der Ordner existiert
function Test-FolderExists {
    return Test-Path $folderPath
}

# Beispielhafte Verwendung der Funktion
if (Test-FolderExists) {
    Write-Host "Ordner existiert." -ForegroundColor Green
} else {
    Write-Host "Ordner existiert NICHT!" -ForegroundColor Red
}

# Überprüfe, ob der Ordner existiert, wenn nicht, warte 0,1 Sekunden und versuche es erneut
while (-not (Test-FolderExists)) {
    # Hole die aktuelle Uhrzeit im Format [hh:mm:ss]
    $currentTime = (Get-Date).ToString("HH:mm:ss")
    Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
    Write-Host " Ordner existiert nicht oder ist nicht erreichbar. Überprüfe erneut..."
    Start-Sleep -Seconds 0.6
    Clear-Host
}

# Erstelle einen FileSystemWatcher, um den Ordner rekursiv zu überwachen
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $folderPath
$watcher.IncludeSubdirectories = $true  # Rekursive Überwachung der Unterordner
$watcher.EnableRaisingEvents = $true     # Ereignisse aktivieren

# Funktion zum Überprüfen der Dateierweiterung
function Is-SupportedExtension($filePath) {
    $extensions = @('.stl', '.3mf', '.f3d')
    $fileExtension = [System.IO.Path]::GetExtension($filePath).ToLower()
    return $extensions -contains $fileExtension
}

# Ereignis-Handler für "Created" (Erstellte Dateien)
$onCreated = Register-ObjectEvent $watcher 'Created' -Action {
    # Prüfen, ob die Datei eine unterstützte Erweiterung hat
    if (Is-SupportedExtension $EventArgs.FullPath) {
        # Berechne den relativen Pfad der Datei zum überwachten Ordner
        $relativePath = $EventArgs.FullPath.Substring($folderPath.Length)
        
        # Hole die aktuelle Uhrzeit im Format [hh:mm:ss]
        $currentTime = (Get-Date).ToString("HH:mm:ss")
        
        # Erstelle den Log-Pfad
        $logFilePath = "$folderPath\00_LogFile\logfile.txt"
        
        # Erstelle das Log-Verzeichnis, falls es nicht existiert
        if (-not (Test-Path "$folderPath\00_LogFile")) {
            New-Item -ItemType Directory -Path "$folderPath\00_LogFile" | Out-Null
        }

        # Prüfen, ob die Datei mit der Endung .f3d erstellt wurde
        if ($relativePath -like "*.f3d") {
            Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
            Write-Host " -------------------------------------------------------------------------------------" -ForegroundColor Green
            Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
            Write-Host " Neue Fusion 360 Datei erstellt: $relativePath" -ForegroundColor Green
            Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
            Write-Host " -------------------------------------------------------------------------------------" -ForegroundColor Green
        } else {
            # Ausgabe der Uhrzeit in Grün und den restlichen Text in Standardfarbe
            Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
            Write-Host " Neue Datei erstellt: $relativePath"
        }
        
        # Logeintrag in die Logdatei schreiben
        $logMessage = "[$currentTime] Neue Datei erstellt: $relativePath"
        $logMessage | Out-File -Append -FilePath $logFilePath
    }
}

# Warten auf Ereignisse
Write-Host "Überwachung gestartet. Drücke [Strg+C] zum Beenden."

try {
    # Endlosschleife, um auf Ereignisse zu warten
    while ($true) {
        Start-Sleep -Seconds 0.4
    }
} catch {
    # Wenn der Benutzer Strg+C drückt, wird hier die Ausnahme abgefangen
    Write-Host "`nSkript wird beendet..."

    # Aufräumen: Unregistriere Ereignisse und stoppe den FileSystemWatcher
    Unregister-Event -SourceIdentifier 'Created'
    $watcher.Dispose()
    Write-Host "Überwachung gestoppt und Ressourcen freigegeben."
}
