# Definiere den Pfad zum Downloads-Ordner des aktuellen Benutzers
$Pfad = "$env:USERPROFILE\Downloads\"

try {
    # Versuche, alle Dateien und Unterordner im Downloads-Ordner zu löschen
    Remove-Item "$Pfad*" -Recurse -Force  # Lösche alle Inhalte im definierten Pfad
    Write-Output "Alle Dateien und Ordner im Downloads-Ordner wurden erfolgreich gelöscht."
} catch {
    Write-Error "Fehler beim Löschen der Dateien und Ordner im Downloads-Ordner: $_"
}