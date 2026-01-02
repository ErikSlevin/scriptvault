# Funktion zum Generieren der Textausgabe mit Punkten für eine bestimmte Länge
function fillWithDots {
    param(
        [string]$Textbaustein,
        [string]$SuccessText,
        [string]$WarningText,
        [string]$ErrorText,
        [switch]$NoNewline
    )

    # Berechnung der Punkte für die Ausgabe
    $PunkteAnzahl = 40 - $Textbaustein.Length
    $Punkte = "." * $PunkteAnzahl

    # Vorbereitung des Ausgabestrings mit dem Textbaustein und den Punkten
    $Ausgabe = " ●  " + $Textbaustein + " " + $Punkte

    Start-Sleep -Seconds 1
    # Ausgabe in verschiedenen Farben je nach Text (Success, Warning, Error)
    if ($SuccessText) {
        if ($NoNewline) {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $SuccessText" -ForegroundColor Green -NoNewline
        } else {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $SuccessText" -ForegroundColor Green
        }
    } elseif ($WarningText) {
        if ($NoNewline) {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $WarningText" -ForegroundColor Yellow -NoNewline
        } else {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $WarningText" -ForegroundColor Yellow
        }
    } elseif ($ErrorText) {
        if ($NoNewline) {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $ErrorText" -ForegroundColor Red -NoNewline
        } else {
            Write-Host -NoNewline $Ausgabe -ForegroundColor White
            Write-Host " $ErrorText" -ForegroundColor Red
        }
    } else {
        Write-Output $Ausgabe
    }
}

Write-Host "`n           A R B E I T S Z E I T   E X P O R T T O O L              " -ForegroundColor Green
Write-Host "===================================================================="
Write-Host
Write-Host "Zweck: Exportiert die HTML-Exportdatei vom Arbeitszeiterfassungstool" -ForegroundColor DarkGray
Write-Host "in eine übersichtlichere, PersDat 1 konforme Übersicht und speichert" -ForegroundColor DarkGray
Write-Host "        diese als HTML- und CSV-Dateien im Netzwerklaufwerk.        " -ForegroundColor DarkGray 
Write-Host
Write-Host "===================================================================="
Write-Host "     2./Informationstechnikbataillon 381 - HptFw Wahl, Erik         `n`n" -ForegroundColor DarkGray


# Bestimme den Pfad des aktuellen Skripts
$currentScriptPath = $PWD.Path

# Definition von Ordnern und Unterordnern
$folders = @{
    "Import" = "01_Import-AZE-Programm"
    "Export" = "02_Export"
}

$subFolders = @{
    "HTML" = "$($folders['Export'])\01_HTML"
    "CSV" = "$($folders['Export'])\02_CSV"
}

# Inhalt für die README-Dateien
$readmeContent = @{
    "Import" = @"
Hier sollten die aktuellsten Export-Dateien aus dem Arbeitszeiterfassungstool abgelegt werden. Das Skript wird automatisch die neuesten Daten auswählen.
"@
    "Export" = @"
In diesem Ordner werden die neuesten exportierten Daten im HTML- und CSV-Format gespeichert. Die CSV-Dateien können für Datenabfragen über mehrere Monate in Excel verwendet werden.

**Anleitung zum Laden einer CSV-Datei in Excel:**

1. Öffnen Sie Excel und erstellen Sie ein neues Arbeitsblatt.
2. Wählen Sie 'Daten' in der Menüleiste aus.
3. Klicken Sie auf 'Aus Text/CSV', um die gewünschte CSV-Datei auszuwählen.
4. Wählen Sie die Datei aus und klicken Sie auf 'Öffnen'.
5. Das 'Textkonvertierungs-Assistent' wird angezeigt. Wählen Sie 'Getrennt' aus, da CSV-Dateien normalerweise durch Trennzeichen wie Semikolons oder Kommas getrennt sind.
6. Wählen Sie das Trennzeichen aus, das in Ihrer CSV-Datei verwendet wird (z. B. Semikolon ';').
7. Klicken Sie auf 'Fertig stellen' und Excel wird die Daten aus der CSV-Datei importieren.
8. Überprüfen Sie die Vorschau und passen Sie die Spaltenformate bei Bedarf an.
9. Klicken Sie auf 'OK', um die Daten in Excel zu importieren.

**Schritte zum Laden und Filtern von CSV-Dateien nach einer bestimmten Personalnummer in Excel:**

1. Öffnen von Excel: 
    Öffnen Sie Microsoft Excel und erstellen Sie ein neues Arbeitsblatt.

2. Daten importieren:
    Klicken Sie auf die Registerkarte "Daten" in der Menüleiste.
    Wählen Sie "Daten abrufen" oder "Daten importieren", je nach Excel-Version.
    Wählen Sie "Aus Ordner" oder "Aus Text/CSV" aus, um auf die CSV-Dateien im gewünschten Ordner zuzugreifen.

3. Ordner auswählen:

    Navigieren Sie zu dem Ordner, der die CSV-Dateien enthält, und wählen Sie diesen aus.
    Excel wird alle CSV-Dateien im Ordner anzeigen. Wählen Sie "Alle laden" oder "Transformieren und laden", um fortzufahren.

4. Power Query Editor:
    In Power Query Editor werden alle geladenen Daten angezeigt.Wählen Sie die Spalte "Person" aus.

5. Filtern nach Personalnummer:
    Klicken Sie auf den Filterpfeil in der Spalte "Person".
    Wählen Sie "Zahlenfilter"
    Wählen Sie "Gleich" , um die Filteroptionen anzuzeigen.
    Geben Sie Ihre Personalnummer in das Filterfeld ein und klicken Sie auf "OK" oder "Übernehmen".

6. Anzeige der gefilterten Daten:
    Nur die Zeilen, die Ihre Personalnummer enthalten, werden jetzt in Excel angezeigt.

7. Aktualisierung der Daten:

    Wenn neue CSV-Dateien im Ordner hinzugefügt werden, aktualisieren Sie die Daten in Excel, indem Sie auf "Daten aktualisieren" oder eine ähnliche Option in Excel klicken.
"@
}

# Erstellung der Ordner und Ausgabe zur Bestätigung
$foldersCreated = $false
foreach ($folder in $folders.Values) {
    $fullPath = Join-Path -Path $currentScriptPath -ChildPath $folder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -Path $fullPath -ItemType Directory | Out-Null
        $foldersCreated = $true
    }
}

foreach ($subFolder in $subFolders.Values) {
    $fullPath = Join-Path -Path $currentScriptPath -ChildPath $subFolder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -Path $fullPath -ItemType Directory | Out-Null
        $foldersCreated = $true
    }
}

# Ausgabe Ordner Struktur
$prefix = "Ordner Struktur"
if ($foldersCreated) {
    fillWithDots -Textbaustein $prefix -WarningText "erstellt!"
    Write-Host "`n    Ordnerstruktur wurde erstellt bzw. repariert." -ForegroundColor Yellow
    Write-Host "    Bitte die Importdatei im Ordner ablegen und das Skript erneut ausführen.`n" -ForegroundColor Yellow
     Exit
} else {
    fillWithDots -Textbaustein $prefix -SuccessText "ok!"
}

# Erstellung der README-Dateien
$readmesCreated = $false
foreach ($key in $readmeContent.Keys) {
    $readmePath = Join-Path -Path $currentScriptPath -ChildPath "$($folders[$key])\README.txt"
    if (-not (Test-Path -Path $readmePath)) {
        $content = $readmeContent[$key]
        Set-Content -Path $readmePath -Value $content
        $readmesCreated = $true
    }
}

# Ausgabe README Dateien
$prefix = "ReadMe-Files"
if ($readmesCreated) {
    fillWithDots -Textbaustein $prefix -WarningText "erstellt!"
} else {
    fillWithDots -Textbaustein $prefix -SuccessText "ok!"
}

# Pfad zur neuesten HTML-Datei im Import-Ordner
$htmlFilePath = Get-ChildItem -Path "$($folders['Import'])" -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

 # HTML Content 
 $htmlContent = Get-Content -Path $htmlFilePath.FullName  -Raw

# Überprüfung, ob eine HTML-Datei gefunden wurde
$prefix = "Einlesen der Exportdatei vom AZE-Tool"
if ($htmlFilePath) {
    fillWithDots -Textbaustein $prefix -SuccessText "ok!" -NoNewline
    Write-Host -ForegroundColor DarkGray " - $htmlFilePath"

    # Finde den Abschnitt mit der Klasse "active"
    $pattern = '(?s)<tr class="active">(.*?)</tr>'
    $matches = [regex]::Match($htmlContent, $pattern)

    $prefix = "Parse Header-Überschriften"
    if ($matches.Success) {
        $activeSection = $matches.Groups[1].Value

        # Finde Daten zwischen <th> und </th> innerhalb des "active" Abschnitts
        $thPattern = '(?s)<th[^>]*>(.*?)</th>'
        $thMatches = [regex]::Matches($activeSection, $thPattern)

        if ($thMatches.Count -gt 0) {
            $updatedContentHeader = ""
            foreach ($match in $thMatches) {
                $data = $match.Groups[1].Value.Trim()
                $updatedContentHeader += "$data;"
            }
            $updatedContentHeader = $updatedContentHeader.TrimEnd(';') # Entferne das letzte Semikolon

            fillWithDots -Textbaustein $prefix -SuccessText "ok!" -NoNewline
            Write-Host -ForegroundColor DarkGray " - $(($updatedContentHeader -split ';').Count) Überschriften extrahiert"
        }
    } else {
        fillWithDots -Textbaustein $prefix -ErrorText "Abschnitt 'active' nicht gefunden."
    }

    # Muster, um den Inhalt vor <tr class="active"> zu entfernen
    $pattern = '(?s).*?<tr class="active">(.*?)</tr>'
    $match = [regex]::Match($htmlContent, $pattern)

    $prefix = "Parsen der relevanten Informationen"
    if ($match.Success) {
        # Entferne den gefundenen Inhalt
        $updatedContent = $htmlContent -replace [regex]::Escape($match.Value), ""
        $updatedContent = $updatedContent -replace "</table></div></div></div></body></HTML>", ""
        $updatedContent = $updatedContent -replace "</th><tr><th>", "</th></tr><tr><th>"
        $updatedContent = $updatedContent -replace "</tr>", "</tr>`r`n"
        $updatedContent = $updatedContent -replace '(?i)<th\s.*?>', '<th>'
        $updatedContent = [regex]::Matches($updatedContent, '<tr>(.*?)</tr>') | ForEach-Object {
            $_.Groups[1].Value -replace '</?th>', ';' -replace ';+', ';' -replace '^;|;$', ''
        }
        fillWithDots -Textbaustein $prefix -SuccessText "ok!"-NoNewline
        Write-Host -ForegroundColor DarkGray " - $(($updatedContent -split "`n").Count) Datensätze extrahiert"
    } else {
        fillWithDots -Textbaustein $prefix -ErrorText "Fehler"
        Write-Host -ForegroundColor DarkGray " - Keine Übereinstimmung gefunden."
    }
} else {
    fillWithDots -Textbaustein $prefix -ErrorText "Fehler"
    Write-Host -ForegroundColor DarkGray " - keine Datei zum Einlesen gefunden!"
}

# Überprüfung, ob eine HTML-Datei gefunden wurde
$prefix = "Exportieren der CSV-Datei"
# Erstelle Ordner für das aktuelle Jahr, falls nicht vorhanden
$yearFolder = Join-Path -Path "$($subFolders['CSV'])" -ChildPath (Get-Date -Format "yyyy")
if (-not (Test-Path -Path $yearFolder)) {
    New-Item -Path $yearFolder -ItemType Directory | Out-Null
}

# Erstelle Ordner für den aktuellen Monat im aktuellen Jahr, falls nicht vorhanden
$monthFolder = Join-Path -Path $yearFolder -ChildPath (Get-Date -Format "MM-MMMM")
if (-not (Test-Path -Path $monthFolder)) {
    New-Item -Path $monthFolder -ItemType Directory | Out-Null
}

# Definiere den Dateinamen mit dem aktuellen Datum und dem gewünschten Präfix
$datePrefix = Get-Date -Format "yyyyMMdd"
$csvFilename = "$($datePrefix)_Daten.csv"

# Definiere den endgültigen Pfad zur CSV-Datei
$csvPath = Join-Path -Path $monthFolder -ChildPath $csvFilename

# Erstelle ein Objekt, das die Überschriften und Daten enthält
$objekte = foreach ($zeile in $datenZeilen) {
    $daten = $zeile -split ';'
    $person = $daten[0]  # Extrahiere den ersten Datensatz für die Person
    $personValue = [regex]::Match($person, '(?<=\-\s)\d{6,8}').Value  # Extrahiere die Personalnummer
    $eintrag = [ordered]@{ 'Person' = $personValue }  # Setze nur die Personalnummer in 'Person'
    
    # Überspringe das erste Element, da es bereits in 'Person' gespeichert ist
    for ($i = 1; $i -lt $ueberschriften.Count; $i++) {
        $eintrag[$ueberschriften[$i]] = $daten[$i]
    }
    [PSCustomObject]$eintrag
}

# Sortiere die Daten nach der Spalte 'Person'
$objekte = $objekte | Sort-Object -Property 'Person'

# Exportiere die Daten in die CSV-Datei
try {
    $objekte | Export-Csv -Path $csvPath  -NoTypeInformation -Delimiter ';' -Encoding UTF8 -ErrorAction Stop
    fillWithDots -Textbaustein $prefix -SuccessText "ok!" -NoNewline
    Write-Host -ForegroundColor DarkGray " - $csvPath"
} catch {
    fillWithDots -Textbaustein $prefix -ErrorText "Fehler"
}


# Definieren des HTML-Inhalts mit Bootstrap-Styling und angepasster Überschrift sowie Abstand
$htmlContent = @"
<!DOCTYPE html>
<html>

<head>
    <title>Personalliste - Kontostand</title>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" rel="stylesheet">

    <style>
        body {
            display: flex;
            flex-direction: column;
            min-height: 100vh;
        }

        .top-margin {
            margin-top: 50px;
        }

        .positive {
            color: green;
        }

        .negative {
            color: red;
        }

        .center-text {
            text-align: center;
            margin-top: 20px;
            margin-bottom: 20px;
        }

        table {
            font-size: small;
        }

        .footer {
            position: sticky;
            bottom: 0;
            background-color: #f2f2f2;
            color: #6c757d;
            padding: 10px;
            font-size: x-small;
        }

    </style>

    <script>
        // Funktion zur Suche nach einer Personalnummer
        function searchByPersonalNumber() {
            var personalNumber = document.getElementById("personalNumber").value; // Holen der eingegebenen Personalnummer

            if (personalNumber !== "") { // Wenn eine Personalnummer vorhanden ist
                // Erstellen des neuen URLs mit der Personalnummer als Anker
                var newUrl = window.location.href.split("?")[0] + "#" + personalNumber;
                window.location.href = newUrl; // Weiterleitung zur neuen URL
                highlightParentElement(personalNumber); // Markieren des Elements mit der eingegebenen Personalnummer
            }
        }

        // Funktion zum Hervorheben des übergeordneten Elements
        function highlightParentElement(personalNumber) {
            var element = document.getElementById(personalNumber); // Holen des Elements mit der entsprechenden ID

            if (element) {
                var tdParent = element.parentNode; // Holen des Eltern-TDs
                if (tdParent && tdParent.tagName.toLowerCase() === "td") { // Überprüfen, ob das Eltern-Element ein TD ist
                    var trParent = tdParent.parentNode; // Holen des Eltern-TRs
                    if (trParent && trParent.tagName.toLowerCase() === "tr") { // Überprüfen, ob das Eltern-Element ein TR ist
                        // Hinzufügen von Klassen, um das TR hervorzuheben
                        trParent.classList.add("table-success");
                        trParent.style.fontWeight = "bold";
                        trParent.scrollIntoView({ behavior: "smooth", block: "center" }); // Scrollen, um das TR in der Mitte anzuzeigen
                        window.scrollBy(0, -100); 
                    }
                }
            }
        }
    </script>
</head>

<body>
    <div class="container top-margin">
        <h1 class="text-center">Personalliste - Kontostand</h1>
        <p class="text-center small-text mb-5">Automatisch generiert am"</p>

        <form class="form-inline justify-content-center" onsubmit="event.preventDefault(); searchByPersonalNumber();">
            <div class="form-group mx-sm-3 mb-2">
                <label for="personalNumber" class="sr-only">Personalnummer</label>
                <input type="text" class="form-control" id="personalNumber" placeholder="Personalnummer">
            </div>
            <button type="submit" class="btn btn-primary mb-2">Suchen</button>
        </form>

        <table class="table table-bordered sticky-header table-sm my-5">
            <thead style="position: sticky;top: 0" class="thead-dark">
                <tr>
                    <th class='text-center'>#</th>
                    <th class='col-2 text-center'>Person</th>
                    <th class='col-2 text-center'>Anspruch</th>
                    <th class='col-2 text-center'>Anspruch > 9M</th>
                    <th class='col-2 text-center'>FVD</th>
                    <th class='col-2 text-center'>FVD > 9M</th>
                    <th class='col-2 text-center'>Langzeitkonto</th>
                </tr>
            </thead>
            <tbody>
"@

# Zähler für die laufende Nummerierung
$rowNumber = 1

# Hinzufuegen der Datenzeilen zur HTML-Tabelle mit Farbformatierung und laufender Nummerierung
foreach ($item in $objekte) {
    $anspruch = $item.('Σ Anspruch Dienstbefreiung')

    # Formatieren des Dienstbefreiungswerts fuer die Anzeige
    if ($anspruch -like '-*') {
        $formattedAns = $anspruch -replace '-', '- '
    } else {
        $formattedAns = "$anspruch"
    }

    $colorClass = if ($anspruch -like '-*') { "negative" } else { "positive" }

    $htmlContent += "<tr>"
    $htmlContent += "<td class='text-center'>$rowNumber</td>"
    $htmlContent += "<td class='text-center'><span id='$($item.'Person')' href='#$($item.'Person')'>$($item.'Person')</span></td>"
    $htmlContent += "<td class='text-center $colorClass'>$formattedAns</td>"
    $htmlContent += "<td class='text-center'>$($item.'Σ Anspruch Dienstbefreiung älter 9M')</span></td>"
    $htmlContent += "<td class='text-center'>$($item.'Σ FvD')</span></td>"
    $htmlContent += "<td class='text-center'>$($item.'Σ FvD älter 9M')</span></td>"
    $htmlContent += "<td class='text-center'>$($item.'Langzeitkonto')</span></td>"
    $htmlContent += "</tr>"
    
    # Erhöhen des Zaehlers fuer die nächste Zeile
    $rowNumber++
}

# Beenden der HTML-Datei mit Copyright im Footer und Link zur E-Mail-Adresse
$htmlContent += @"
            </tbody>
        </table>
    </div>
    <footer class="footer">
        <div class="container">
            <div class="row ">
                <div class="col-md-4">
                    <a class="text-muted" href="mailto:erikwahl@bundeswehr.org?subject=Anmerkung: Personalliste - Kontostand&body=Guten Tag,%0D%0A%0D%0AIch möchte folgendes mitteilen:%0D%0A%0D%0A- Verbesserungsvorschläge%0D%0A- Feedback%0D%0A- Fehler in der Darstellung%0D%0A%0D%0AHinweis: Bitte beachten Sie, dass ich keine Fragen zur Arbeitszeiterfassung beantworten kann. Bei Fragen dazu wenden Sie sich bitte an den zuständigen AZE-Bearbeiter.%0D%0A%0D%0APersonalliste - Kontostand: $dateTime%0D%0A%0D%0A">
                        &copy; HptFw Wahl - 2./Informationstechnikbataillon 381
                    </a>
                </div>
                <div class="col-md-4 text-center">
                    VS - Nur für den Dienstgebrauch
                </div>
                <div class="col-md-4 text-right">
                    Schutzbereich 1
                </div>
            </div>
        </div>
    </footer>

    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>
</body>
</html>
"@


# Speichere das HTML in einer Datei
$htmlContent | Set-Content -Path $htmlPath -Encoding UTF8

# Ausgabe zur Bestätigung
$prefix = "Exportieren der HTML-Datei"
if (Test-Path -Path $htmlPath) {
    fillWithDots -Textbaustein $prefix -SuccessText "ok!"
    Write-Host -ForegroundColor DarkGray " - $htmlPath"
} else {
    fillWithDots -Textbaustein $prefix -ErrorText "Fehler"
}
