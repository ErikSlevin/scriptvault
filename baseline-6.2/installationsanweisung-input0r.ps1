Clear-Host

# 🛠 Interaktive Abfrage des Suchpfads
$searchPath = Read-Host "📂 Bitte geben Sie den Suchpfad ein"

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

    # Objekt zur Liste hinzufügen
    $outputList += [PSCustomObject]@{
        "Nr."       = $counter
        "Titel"     = $highlightPart
        "Dateiname" = "$filename"
    }

    $counter++
}

# Maximale Länge des Titels anhand der tatsächlichen Zeichenbreite ermitteln
$maxTitleLength = ($outputList | ForEach-Object { ($_.Titel -replace '[^\x00-\x7F]', '??') }).ForEach({ $_.Length }) | Measure-Object -Maximum
$maxTitleLength = $maxTitleLength.Maximum

# Ausgabe mit korrekter Ausrichtung
foreach ($item in $outputList) {
    # Nummerierung anpassen (einstellige Nummern erhalten ein zusätzliches Leerzeichen)
    $formattedNumber = if ($item.'Nr.' -lt 10) { " $($item.'Nr.')." } else { "$($item.'Nr.')." }

    $paddedTitle = $item.Titel.PadRight($maxTitleLength + 2)  # Titel mit Leerzeichen auffüllen

    # Farbliche Ausgabe
    Write-Host "$formattedNumber " -NoNewline
    Write-Host -ForegroundColor Cyan "$paddedTitle" -NoNewline  # Titel farbig
    Write-Host -ForegroundColor DarkGray " $($item.Dateiname)"  # Dateiname dunkelgrau
}
