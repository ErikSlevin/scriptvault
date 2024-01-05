# Pfade definieren
$folderPath = "C:\Users\erikw\Documents\GitHub\3d-printing\filament"
$outputFilePath = "C:\Users\erikw\Documents\GitHub\3d-printing\README.md"

# Lese die Translatedateien ein
$Datei1 = Get-Content -Path "C:\Users\erikw\Documents\GitHub\scriptvault\filament-settings-crawler\fdmextruder.def.json.po" -Encoding UTF8
$Datei2 = Get-Content -Path "C:\Users\erikw\Documents\GitHub\scriptvault\filament-settings-crawler\fdmprinter.def.json.po" -Encoding UTF8

function SucheUndSpeichereZeilennummern {
    param (
        [string]$Suchwort
    )

    $Zeilennummer1 = 1
    $Zeilennummer2 = 1
    $Gefunden1 = $false
    $Gefunden2 = $false

    $Pattern = "msgctxt `"$Suchwort label`""

    foreach ($Zeile in $Datei1) {
        if ($Zeile -match $Pattern) {
            $Gefunden1 = $true
            $gefundeneZeile = $Datei1[$Zeilennummer1 + 1]
            $gefundeneZeile = $gefundeneZeile -replace 'msgstr "', '' -replace '"', ''

            return $gefundeneZeile
            # Write-Host "$Suchwort, Inhalt: $gefundeneZeile"
            break
        }
        $Zeilennummer1++
    }

    foreach ($Zeile in $Datei2) {
        if ($Zeile -match $Pattern) {
            $Gefunden2 = $true
            $gefundeneZeile = $Datei2[$Zeilennummer2 + 1]
            $gefundeneZeile = $gefundeneZeile -replace 'msgstr "', '' -replace '"', ''
            # Write-Host "$Suchwort, Inhalt: $gefundeneZeile"
            return $gefundeneZeile
            break
        }
        $Zeilennummer2++
    }

    if (-not $Gefunden1 -and -not $Gefunden2) {
        Write-Host "Nicht in beiden Dateien gefunden"
    }
}

# Suche nach .curaprofile-Dateien im Ordner
$files = Get-ChildItem -Path $folderPath -Filter *.curaprofile

# Erstelle oder leere die readme.md
Set-Content -Path $outputFilePath -Value ""

# Erhalte den aktuellen Zeitstempel
$currentDateTime = Get-Date

# Füge den Überschrit der Datei hinzu
Add-Content -Path $outputFilePath -Value "# Filament Settings"

# Füge den Zeitstempel der Datei hinzu
Add-Content -Path $outputFilePath -Value "> Diese Datei wurde zuletzt am $currentDateTime automatisch generiert."

# Erstelle ein Array für die Werte
$propertyValues = @{}

# Iteriere durch jede .curaprofile-Datei
foreach ($file in $files) {
    # Lese den Inhalt der Datei
    $content = Get-Content -Path $file.FullName

    # Extrahiere den Profilnamen (nur den ersten Treffer)
    $name = ($content | Select-String -Pattern "name = (.*)" | Select-Object -First 1 | ForEach-Object { $_.Matches.Groups[1].Value }).Trim()

    # Starte das Schreiben in readme.md mit der Überschrift
    Add-Content -Path $outputFilePath -Value "## $name`n"

    # Starte das Extrahieren der Werte
    $writing = $false
    foreach ($line in $content) {
        if ($line -match "^\[values\]") {
            $writing = $true
            continue
        }

        if ($writing -and [string]::IsNullOrWhiteSpace($line)) {
            $writing = $false
            continue  # Entferne die leeren Zeilen
        }

        if ($writing) {
            # Extrahiere und speichere die Werte
            if ($line -match '^\s*(\w+)\s*=\s*(.+)') {
                $propertyName = $matches[1].Trim()
                $translation = SucheUndSpeichereZeilennummern -Suchwort $propertyName

                if (-not $propertyValues.ContainsKey($propertyName)) {
                    $propertyValues[$propertyName] = ""
                }
            }
            $translate = $line -replace [regex]::Escape($propertyName), $translation

            # Ersetze "True" durch "Ja"
            $translate  = $translate  -replace '\bTrue\b', 'Ja'

            # Ersetze "False" durch "Nein"
            $translate = $translate -replace '\bFalse\b', 'Nein'

            # Ersetze "None" durch "Keine"
            $translate  = $translate  -replace '\bNone\b', 'Keine'

            # Schreibe die Zeilen in die readme.md
            Add-Content -Path $outputFilePath -Value $translate.Trim() -Encoding UTF8
        }
    }

    # Füge eine leere Zeile nach jedem Profil hinzu
    Add-Content -Path $outputFilePath -Value "`n"
}

