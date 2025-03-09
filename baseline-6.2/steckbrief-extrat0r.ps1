Clear-Host

# 🛠 Interaktive Abfrage des Suchpfads
$searchPath = Read-Host "📂 Bitte geben Sie den Suchpfad ein"

# 🔍 Suche nach allen Excel-Dateien, die auf ein Datum (YYYYMMDD) enden
$regexPattern = "\d{8}\.xlsx$"
$allFiles = Get-ChildItem -Path $searchPath -Filter "*.xlsx" -Recurse | Where-Object { $_.Name -match $regexPattern }

# Wenn keine Dateien mit Datumsmuster gefunden wurden, den Benutzer nach einem Datumsmuster fragen
if ($allFiles.Count -eq 0) {
    Write-Host ""
    Write-Host "❌ Keine Dateien mit Datumsformat (YYYYMMDD) gefunden!"
    $useCustomDate = Read-Host "Bitte geben Sie das Datumsmuster (YYYYMMDD) ein, nach dem gesucht werden soll"
    
    # Dateien nach dem vom Benutzer angegebenen Datumsmuster filtern
    $files = Get-ChildItem -Path $searchPath -Filter "*.xlsx" -Recurse | Where-Object { $_.Name -match $useCustomDate }
    
    if ($files.Count -eq 0) {
        Write-Host "❌ Keine Dateien gefunden, die dem angegebenen Datumsmuster entsprechen!"
        exit
    }
} else {
    Write-Host ""
    # Wenn Dateien mit dem Datumsformat gefunden wurden, dem Benutzer die Wahl lassen
    Write-Host "================ Gefundene Dateien ================" -ForegroundColor Cyan
    $allFiles | ForEach-Object { Write-Host "📄 $_.Name" -ForegroundColor Yellow }
    Write-Host ""

    # Benutzer fragen, ob alle verarbeitet oder ein anderes Datum eingegeben werden soll
    $useCustomDate = Read-Host "Möchten Sie alle gefundenen Dateien verarbeiten (Ja) oder ein Datum eingeben (YYYYMMDD)?"

    if ($useCustomDate -match "^\d{8}$") {
        # Falls ein gültiges Datum eingegeben wurde, erneut nach Dateien filtern
        $files = $allFiles | Where-Object { $_.Name -match $useCustomDate }
    } else {
        $files = $allFiles
    }
}

if ($useCustomDate -match "^\d{8}$") {
    # Falls ein gültiges Datum eingegeben wurde, erneut nach Dateien filtern
    $files = $allFiles | Where-Object { $_.Name -match $useCustomDate }
} else {
    $files = $allFiles
}

# Überprüfen, ob nach der erneuten Filterung noch Dateien vorhanden sind
if ($files.Count -eq 0) {
    Write-Host "❌ Keine Dateien gefunden, die dem Suchmuster entsprechen!"
    exit
}

Write-Host ""
Write-Host "================ Verarbeitung ================" -ForegroundColor Cyan
Write-Host ""

# Pfad für die neue Datei
$newFilePath = Join-Path -Path $searchPath -ChildPath "Generierter Steckbrief by Erik.xlsx"

# Excel-Anwendung starten
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false

# Bestehende Datei öffnen oder neu erstellen
if (Test-Path $newFilePath) {
    $newWorkbook = $excel.Workbooks.Open($newFilePath)
} else {
    $newWorkbook = $excel.Workbooks.Add()
}

# 🏗 Verarbeitung aller Excel-Dateien
foreach ($file in $files) {
    Write-Host "🔄 Bearbeite: $($file.Name)" -ForegroundColor Yellow

    $excelFilePath = $file.FullName
    $folderName = (Get-Item -Path $excelFilePath).Directory.Name

    # Original-Workbook öffnen
    $workbook = $excel.Workbooks.Open($excelFilePath)
    
    # Neues Arbeitsblatt am Ende anlegen
    $newSheet = $newWorkbook.Sheets.Add()
    $newSheet.Name = $folderName

    # Sicherstellen, dass das neue Arbeitsblatt am Ende eingefügt wird
    $newSheet.Move($newWorkbook.Sheets[$newWorkbook.Sheets.Count])

    # Spaltenbreiten setzen
    $newSheet.Columns.Item(1).ColumnWidth = 12
    $newSheet.Columns.Item(2).ColumnWidth = 60
    $newSheet.Columns.Item(3).ColumnWidth = 60

    $rowIndex = 2
    $lastBValue = ""

    # Arbeitsblätter durchlaufen
    foreach ($sheet in $workbook.Sheets) {
        if ($sheet.Name -eq "Deckblatt" -or $sheet.Name -eq "Änderungsregister") { continue }

        $lastRow = $sheet.Cells($sheet.Rows.Count, 2).End(3).Row

        for ($i = 1; $i -le $lastRow; $i++) {
            $valueB = $sheet.Cells($i, 2).Value2
            $valueC = $sheet.Cells($i, 3).Value2
            $valueD = $sheet.Cells($i, 4).Value2

            # Werte bereinigen
            if ($valueB -ne $null) {
                $valueB = $valueB -replace "[\r\n]+", " " -replace "\s+", " " -replace "^\s+|\s+$", ""
            }

            if ($valueB -eq $null -and $valueD -ne $null) {
                $valueB = "   |->"  # Statt den letzten Wert → Zeichen "0x39"
            }
            
            if ($valueB -ne $null) { $lastBValue = $valueB }

            # Bedingung: Zeilen überspringen, wenn die Spalten genau diese Werte enthalten
            if (($valueB -eq "Index" -or $valueB -eq "Bezeichnung" -or $valueB -eq "Wert") -and 
                ($valueC -eq "Index" -or $valueC -eq "Bezeichnung" -or $valueC -eq "Wert") -and 
                ($valueD -eq "Index" -or $valueD -eq "Bezeichnung" -or $valueD -eq "Wert")) {
                continue
            }

            # Bedingung: Zeilen überspringen, bei denen alle Spalten leer sind
            if ($valueB -eq $null -and $valueC -eq $null -and $valueD -eq $null) {
                continue
            }

            # Werte einfügen
            if ($newSheet -ne $null) {
                $newSheet.Cells.Item($rowIndex, 1).Value2 = $valueB
                $newSheet.Cells.Item($rowIndex, 2).Value2 = [string]$valueD
                $newSheet.Cells.Item($rowIndex, 3).Value2 = [string]$valueC
                $rowIndex++
            }
        }
    }

    # Tabelle formatieren
    $tableRange = $newSheet.Range("A1:C" + ($rowIndex - 1))
    $table = $newSheet.ListObjects.Add(1, $tableRange)
    $table.Name = "Tabelle1"

    # Formatierungen setzen
    $newSheet.Columns.Item(1).Font.Bold = $true
    $newSheet.Cells.WrapText = $false

    # Zellenformatierung für Spalten
    # 1. Spalte (Spalte A) zentrieren
    $newSheet.Columns.Item(1).HorizontalAlignment = -4108  # -4108 entspricht der Zentrierung

    # 2. und 3. Spalte (Spalten B und C) linksbündig
    $newSheet.Columns.Item(2).HorizontalAlignment = -4131  # -4131 entspricht der linken Ausrichtung
    $newSheet.Columns.Item(3).HorizontalAlignment = -4131  # -4131 entspricht der linken Ausrichtung

    # Original-Workbook schließen
    if ($workbook -ne $null) {
        try { $workbook.Close($false) } catch {}
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
        $workbook = $null
    }
}

Write-Host ""

# Leeres Standardblatt entfernen
$tabelle1 = $newWorkbook.Sheets | Where-Object { $_.Name -eq "Tabelle1" -and $_.UsedRange.Rows.Count -eq 1 }
if ($tabelle1) { $tabelle1.Delete() }

# Leere Zeilen und Zeilen löschen, bei denen nur Spalte 1 einen Wert hat und Spalte 2 und 3 leer sind
$rowIndexToDelete = @()

for ($i = 1; $i -le $newSheet.UsedRange.Rows.Count; $i++) {
    $valueA = $newSheet.Cells.Item($i, 1).Value2
    $valueB = $newSheet.Cells.Item($i, 2).Value2
    $valueC = $newSheet.Cells.Item($i, 3).Value2

    # Prüfen, ob alle Spalten leer sind
    if ($valueA -eq $null -and $valueB -eq $null -and $valueC -eq $null) {
        # Leere Zeile
        $rowIndexToDelete += $i
    }
    # Prüfen, ob nur Spalte 1 einen Wert hat und Spalte 2 und 3 leer sind
    elseif ($valueA -ne $null -and $valueB -eq $null -and $valueC -eq $null) {
        # Zeile, bei der nur Spalte 1 einen Wert hat
        $rowIndexToDelete += $i
    }
}

# Lösche die markierten Zeilen (von unten nach oben, um Indizes nicht durcheinander zu bringen)
$rowIndexToDelete = $rowIndexToDelete | Sort-Object -Descending

foreach ($index in $rowIndexToDelete) {
    $newSheet.Rows.Item($index).Delete() | Out-Null
}

# Neue Datei speichern
$newWorkbook.SaveAs($newFilePath)

# Ressourcen bereinigen
if ($newWorkbook -ne $null) {
    try { $newWorkbook.Close($true) } catch {}
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newWorkbook) | Out-Null
    $newWorkbook = $null
}

if ($excel -ne $null) {
    try { $excel.Quit() } catch {}
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    $excel = $null
}

# 🗑 Garbage Collector
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "✅ Verarbeitung abgeschlossen: $(Split-Path $newFilePath -Leaf) wurde erfolgreich erstellt!" -ForegroundColor Green