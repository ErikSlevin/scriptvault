Clear-Host

# 🛠 Interaktive Abfrage des Suchpfads
$searchPath = Read-Host "📂 Bitte geben Sie den Suchpfad ein"
Write-Host ""
Write-Host "============================ Gefundene Dateien ============================" -ForegroundColor Cyan
Write-Host ""

# Prüfen, ob der angegebene Pfad existiert
if (-Not (Test-Path $searchPath)) {
    Write-Host "🚨 Der angegebene Pfad existiert nicht." -ForegroundColor Red
    exit
}

# Alle .docx-Dateien im angegebenen Pfad finden (inklusive Unterordner)
$files = Get-ChildItem -Path $searchPath -Recurse -Filter "*.docx"

# Wenn keine .docx-Dateien gefunden werden
if ($files.Count -eq 0) {
    Write-Host "📄 Keine .docx-Dateien im angegebenen Verzeichnis gefunden." -ForegroundColor Yellow
    exit
}

# Liste ignorierter Begriffe (Teilstrings von Dateinamen)
$ignoredPatterns = @("GNBK", "Integrationsvorbereitung", "Admin-Guide", "Generisches Netzbetriebskonzept")

# Array für die Verarbeitung
$outputList = @()

# Ermitteln der Titel-Längen
$counter = 1
foreach ($file in $files) {
    $filename = $file.Name
    $fullPath = $file.FullName  # Vollständigen Pfad speichern

    # Prüfen, ob einer der Ignore-Begriffe im Dateinamen enthalten ist
    if ($ignoredPatterns | Where-Object { $filename -match $_ }) {
        continue
    }

    $extension = ".docx"
    $baseName = $filename.Substring(0, $filename.Length - $extension.Length)

    # Ersten Unterstrich finden
    $underscoreIndex = $baseName.IndexOf('_')
    if ($underscoreIndex -eq -1) {
        $highlightPart = $baseName
    } else {
        $highlightPart = $baseName.Substring($underscoreIndex + 1) # Teil nach dem Unterstrich
    }

    # Objekt zur Liste hinzufügen, einschließlich des vollständigen Pfads
    $outputList += [PSCustomObject]@{
        "Nr."       = $counter
        "Titel"     = $highlightPart
        "Dateiname" = "📄 $filename"
        "Pfad"      = $fullPath  # Speichern des vollständigen Pfads
    }

    $counter++
}

# Maximale Länge des Titels ermitteln
$maxTitleLength = ($outputList | ForEach-Object { ($_.Titel -replace '[^\x00-\x7F]', '??') }).ForEach({ $_.Length }) | Measure-Object -Maximum
$maxTitleLength = $maxTitleLength.Maximum

# Ausgabe mit korrekter Ausrichtung
foreach ($item in $outputList) {
    # Nummerierung anpassen (einstellige Nummern erhalten ein zusätzliches Leerzeichen)
    $formattedNumber = if ($item.'Nr.' -lt 10) { " $($item.'Nr.')." } else { "$($item.'Nr.')." }

    $paddedTitle = $item.Titel.PadRight($maxTitleLength + 2)  # Titel mit Leerzeichen auffüllen

    # Farbliche Ausgabe (Dateiname nicht ausgeben)
    Write-Host "$formattedNumber " -NoNewline
    Write-Host -ForegroundColor Cyan "$paddedTitle" -NoNewline  # Titel farbig
    Write-Host -ForegroundColor DarkGray " $($item.Dateiname)"  # Dateiname dunkelgrau
}

# 🛠 Nutzer soll Nummern eingeben
Write-Host ""
$selectionInput = Read-Host "✏️  Bitte geben Sie die Nummern der zu bearbeitenden Dateien ein (kommagetrennt)"

# Konvertiere die Eingabe in eine Liste von gültigen Nummern
$selectedNumbers = $selectionInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }

# Prüfe, ob eingegebene Nummern in der Liste existieren
$validSelections = $outputList | Where-Object { $_."Nr." -in $selectedNumbers }

if ($validSelections.Count -eq 0) {
    Write-Host "🚨 Keine gültigen Nummern eingegeben. Das Skript wird beendet." -ForegroundColor Red
    exit
}

# Maximale Länge der ausgewählten Titel für saubere Formatierung
$maxSelectedTitleLength = ($validSelections | ForEach-Object { ($_.Titel -replace '[^\x00-\x7F]', '??') }).ForEach({ $_.Length }) | Measure-Object -Maximum
$maxSelectedTitleLength = $maxSelectedTitleLength.Maximum

# Bestätigung der Auswahl mit richtiger Formatierung
Write-Host ""
Write-Host "✅ Sie haben folgende Dateien zur Bearbeitung ausgewählt:" -ForegroundColor Green
foreach ($item in $validSelections) {
    # Nummerierung anpassen (einstellige Nummern erhalten ein zusätzliches Leerzeichen)
    $formattedNumber = if ($item.'Nr.' -lt 10) { " $($item.'Nr.')." } else { "$($item.'Nr.')." }

    # Titel mit Leerzeichen auffüllen, basierend auf der maximalen Länge der ausgewählten Dateien
    $paddedTitle = $item.Titel.PadRight($maxSelectedTitleLength + 2)

    # Farbliche Ausgabe (Dateiname nicht ausgeben)
    Write-Host "✔ $formattedNumber " -NoNewline
    Write-Host -ForegroundColor Cyan "$paddedTitle" -NoNewline  # Titel farbig
    Write-Host -ForegroundColor DarkGray " $($item.Dateiname)"  # Dateiname dunkelgrau
}

# **Jetzt hast du den vollständigen Pfad gespeichert und kannst mit diesen weiterarbeiten!**

Write-Host ""
Write-Host "🚀 Fertig! Jetzt können Sie die ausgewählten Dateien bearbeiten."
