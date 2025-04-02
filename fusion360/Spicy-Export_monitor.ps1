# Pfad des zu überwachenden Ordners
$folderPath = "C:\Users\erikw\Desktop\Gewuerze"

# Funktion zum Überprüfen, ob der Ordner existiert
function Test-FolderExists {
    return Test-Path $folderPath
}

# Überprüfe, ob der Ordner existiert, wenn nicht, warte 0,1 Sekunden und versuche es erneut
while (-not (Test-FolderExists)) {
    Write-Host "Ordner existiert nicht oder ist nicht erreichbar. Überprüfe erneut..."
    Start-Sleep -Seconds 0.3
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
        
        # Ausgabe der Uhrzeit in Grün und den restlichen Text in Standardfarbe
        Write-Host -NoNewline ("[$currentTime]") -ForegroundColor Green
        Write-Host " Neue Datei erstellt: $relativePath"
    }
}


# Warten auf Ereignisse
Write-Host "Überwachung gestartet. Drücke [Strg+C] zum Beenden."

try {
    # Endlosschleife, um auf Ereignisse zu warten
    while ($true) {
        Start-Sleep -Seconds 0.1
    }
} catch {
    # Wenn der Benutzer Strg+C drückt, wird hier die Ausnahme abgefangen
    Write-Host "`nSkript wird beendet..."

    # Aufräumen: Unregistriere Ereignisse und stoppe den FileSystemWatcher
    Unregister-Event -SourceIdentifier 'Created'
    $watcher.Dispose()
    Write-Host "Überwachung gestoppt und Ressourcen freigegeben."
}
