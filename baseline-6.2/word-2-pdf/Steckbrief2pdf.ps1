﻿# Funktion zur Konvertierung von Excel zu PDF
function Convert-ExcelToPDF {
    param (
        [string]$excelFilePath,  # Pfad zur Excel-Datei
        [string]$pdfFilePath     # Pfad zur Ausgabe-PDF
    )

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false

    try {
        $workbook = $excel.Workbooks.Open($excelFilePath)
        $workbook.ExportAsFixedFormat(0, $pdfFilePath)  # 0 = PDF

        # Originalname ohne Erweiterung
        $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($pdfFilePath)

        # Suche nach den letzten 3 Ziffern im Dateinamen + restlichen Namen
        if ($fileNameWithoutExt -match "(\d{3})_(.*?)_(\d{8})$") {
            $numbers = $matches[1]  # Die 3 Ziffern extrahieren
            $namePart = $matches[2]  # Der restliche Name (z.B. Active-Directory)
            
            # Neuen Dateinamen zusammenbauen
            $newFileName = "$numbers" + "_" + "$namePart" + ".pdf"
            Write-Host -ForegroundColor Green "📄 $newFileName"
        } else {
            # Wenn der reguläre Ausdruck nicht passt, verwende den ursprünglichen Dateinamen ohne Erweiterung
            Write-Host "❌ Fehler: Kein gültiges Format im Dateinamen gefunden!"
            $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($pdfFilePath) + ".pdf"  # Fallback-Name
        }
    }
    catch {
        Write-Host "❌ Fehler beim Konvertieren: $_"
        $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($pdfFilePath) + ".pdf"  # Fallback-Name
    }
    finally {
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    }

    return $newFileName
}

Clear-Host

# 🛠 Interaktive Abfrage des Suchpfads
$searchPath = Read-Host "📂 Bitte geben Sie den Suchpfad ein"

# 🔍 Suche nach allen Excel-Dateien, die auf ein Datum (YYYYMMDD) enden
$regexPattern = "\d{8}\.xlsx$"
$allFiles = Get-ChildItem -Path $searchPath -Filter "*.xlsx" -Recurse | Where-Object { $_.Name -match $regexPattern }

if ($allFiles.Count -eq 0) {
    Write-Host ""
    Write-Host "❌ Keine Dateien mit Datumsformat (YYYYMMDD) gefunden!"
    exit
} else {
    Write-Host ""
    Write-Host "================ $($allFiles.Count) Gefundene Steckbriefe ================" -ForegroundColor Cyan
    $allFiles | ForEach-Object { Write-Host "📄 $_" -ForegroundColor Yellow }
    Write-Host ""
}

# Speicherort für die konvertierten PDFs
$pdfOutputDir = Join-Path -Path $searchPath -ChildPath "99_PDF_by_Wahl\Steckbriefe"

# 🛠 Interaktive Abfrage, ob die gefundenen Dateien konvertiert werden sollen
$convertFiles = Read-Host " Mit diesen $($allFiles.Count) Steckbriefen fortfahren? (Ja/Nein)"
Write-Host ""

if ($convertFiles -ne "ja") {
    # Abfrage nach einem neuen Suchmuster für das Datum
    $newPattern = Read-Host "📂 Geben Sie das neue Suchmuster (YYYYMMDD) ein, um nach Dateien zu suchen"
    $regexPattern = "$newPattern\.xlsx$"  # Neues Suchmuster
    $allFiles = Get-ChildItem -Path $searchPath -Filter "*.xlsx" -Recurse | Where-Object { $_.Name -match $regexPattern }

    if ($allFiles.Count -eq 0) {
        Write-Host ""
        Write-Host "❌ Keine Dateien für das Muster $newPattern gefunden!"
        exit
    } else {
        Write-Host ""
        Write-Host "================ $($allFiles.Count) Gefundene Dateien ================" -ForegroundColor Cyan
        $allFiles | ForEach-Object { Write-Host "📄 $_" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "Gefundene Dateien: $($allFiles.Count)"  # Anzahl der gefundenen Dateien anzeigen
    }
}

# 🛠 Abfrage nach dem Pfad zur pdfcpu.exe
Write-Host "====================== pdfcpu.exe ======================" -ForegroundColor Cyan
Write-Host "📂  Download: https://github.com/pdfcpu/pdfcpu" -ForegroundColor DarkGray
$pdfcpu = Read-Host "📂  Pfad zu der EXE-Datei"
$pdfcpu = $pdfcpu.Trim().Replace('"', '')

if (-Not (Test-Path $pdfcpu)) {
    Write-Host "❌ pdfcpu.exe wurde nicht gefunden!"
    exit
} else {
    Write-Host "✅  pdfcpu.exe gefunden" -ForegroundColor Green
    Write-Host ""
}

# 🛠 Interaktive Abfrage, ob die gefundenen Dateien konvertiert werden sollen
Write-Host ""
Write-Host "==================== Konvertierung ====================" -ForegroundColor Cyan
Write-Host   " Speicherort: $pdfOutputDir\YYYYMMDD" -ForegroundColor DarkGray
$convertFiles = Read-Host " Steckbrief Konvertierung starten? (Ja/Nein)"
Write-Host ""

# Alle gefundenen Excel-Dateien konvertieren
foreach ($file in $allFiles) {
    if ($file.Name -match "(\d{8})") {
        $dateFolder = $matches[1]
    } else {
        Write-Host "❌ Kein gültiges Datum im Dateinamen gefunden!"
        continue
    }

    # Zielordner mit Datum erstellen
    $pdfOutputDirWithDate = Join-Path -Path $pdfOutputDir -ChildPath $dateFolder
    if (!(Test-Path $pdfOutputDirWithDate)) {
        New-Item -ItemType Directory -Path $pdfOutputDirWithDate | Out-Null
    }

    # Erzeuge die PDF-Datei im passenden Ordner
    $pdfFilePath = Join-Path -Path $pdfOutputDirWithDate -ChildPath "$($file.BaseName).pdf"
    $newPdfFileName = Convert-ExcelToPDF -excelFilePath $file.FullName -pdfFilePath $pdfFilePath

    # Überprüfen, ob der neue Dateiname korrekt ist
    if ($newPdfFileName) {
        $newPdfFilePath = Join-Path -Path $pdfOutputDirWithDate -ChildPath $newPdfFileName

        # Überprüfen, ob die Datei bereits existiert
        if (Test-Path $newPdfFilePath) {
            Write-Host "⚠️ Die Datei $newPdfFilePath existiert bereits. Datei wird überschrieben."
            Remove-Item -Path $newPdfFilePath -Force  # Löschen der existierenden Datei
        }

        # Die PDF-Datei umbenennen
        Rename-Item -Path $pdfFilePath -NewName $newPdfFilePath
    } else {
        Write-Host "❌ Kein gültiger Dateiname für $($file.Name) erstellt!"
    }
}

Write-Host ""
Write-Host "✅ Konvertierung abgeschlossen!"
Write-Host ""
Write-Host "   Die PDFs befinden sich im Ordner: $pdfOutputDirWithDate" -ForegroundColor Cyan
Write-Host ""
Write-Host ""
