# Quelle und Ziel definieren
$esdFile = "D:\RemoteInstall\ISOCopy\install.esd"
$zielOrdner = "D:\RemoteInstall\ISOCopy\ExtractedWIMs"

# Zielordner erstellen, falls nicht vorhanden
if (!(Test-Path -Path $zielOrdner)) {
    New-Item -ItemType Directory -Path $zielOrdner -Force
}

# Alle Images auflisten (DISM-Ausgabe einlesen)
$wimInfo = dism /Get-WimInfo /WimFile:$esdFile

# Alle Index-Zeilen herausfiltern
$indices = @()

foreach ($line in $wimInfo) {
    # Zeile trimmen und prüfen, ob sie mit "Index:" beginnt
    if ($line.TrimStart().StartsWith("Index:")) {
        # Indexnummer extrahieren
        $indexNumber = ($line -replace '[^\d]', '')
        $indices += $indexNumber
    }
}

# Jetzt für jeden Index eine eigene WIM-Datei exportieren
foreach ($index in $indices) {
    $zielWim = "$zielOrdner\install_$index.wim"

    Write-Host "Exportiere Index $index nach $zielWim ..." -ForegroundColor Cyan

    dism /Export-Image /SourceImageFile:$esdFile /SourceIndex:$index /DestinationImageFile:$zielWim /Compress:Max /CheckIntegrity
}

Write-Host "Alle Editionen wurden erfolgreich exportiert!" -ForegroundColor Green
