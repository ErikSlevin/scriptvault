# Definition der Client-Liste mit zugehörigen IP-Adressen
$clientData = @{
    'DC01' = '172.16.3.11'
    'DC02' = '172.16.3.12'
    'NP01' = '10.0.0.200'
    'FS01' = '10.0.0.3'
    'FS02' = '10.0.0.2'
    'FS03' = '10.0.0.1'
}

# Erstellen und Sortieren der Client-Daten
$clients = $clientData.GetEnumerator() | 
    Sort-Object -Property {
        # Teile die IP-Adresse in Oktette, füge Null-Padding hinzu und verbinde sie zurück
        [String]::Join('.', ($_.Value.Split('.') | ForEach-Object { "{0:D3}" -f [int]$_ }))
    } | ForEach-Object {
        # Erstelle ein PSCustomObject für jeden Client mit Name, IP und Status
        [PSCustomObject]@{
            Name   = $_.Key
            IP     = $_.Value
            Status = 'Ping ausstehend' # Anfangsstatus
        }
    }

# Konstanten für den Status
$Status = @{
    Online  = "Online"
    Offline = "Offline"
    Pending = "Ping ausstehend"
    Error   = "Fehler beim Verbinden"
}

# Funktion zur Anzeige von Clients in Tabellenform
function Display-ClientTable {
    param (
        [psobject[]]$clientsList, # Liste der Clients
        [string]$color             # Textfarbe
    )

    # Header für die Tabelle formatieren
    $header = "{0,-15} {1,-20} {2,-15}" -f "Name", "IP", "Status"
    Write-Host $header -ForegroundColor $color
    Write-Host ("-" * ($header.Length)) -ForegroundColor $color

    # Durchlaufen der Clients für die Anzeige
    foreach ($client in $clientsList) {
        $line = "{0,-15} {1,-20} {2,-15}" -f $client.Name, $client.IP, $client.Status
        Write-Host $line -ForegroundColor $color
    }
}

# Funktion zur Aktualisierung des Client-Status durch einen Ping-Test
function Update-ClientStatus {
    param (
        [pscustomobject]$client # Der Client, dessen Status aktualisiert werden soll
    )

    try {
        # Teste die Verbindung zum Client mit Timeout und mehreren Pings
        $pingResult = Test-Connection -ComputerName $client.IP -Count 2 -Quiet

        # Aktualisiere den Status basierend auf dem Ping-Ergebnis
        if ($pingResult) {
            $client.Status = $Status.Online
        } else {
            $client.Status = $Status.Offline
        }
    } catch {
        # Fehlerbehandlung für alle Arten von Ping-Fehlern
        $client.Status = $Status.Error
    }
}

# Bildschirm leeren für eine saubere Ausgabe
Clear-Host

# Hauptschleife: Durchlaufen der sortierten Client-Liste
foreach ($client in $clients) {
    # Bildschirm leeren für die nächste Ausgabe
    Clear-Host

    # Anzeige der aktuellen IP, die überprüft wird
    Write-Host ""
    Write-Host "Überprüfe derzeit: $($client.IP)" -ForegroundColor Yellow
    Write-Host ""

    # Anzeige der Clients sortiert nach Status vor dem Pingen
    Display-ClientTable -clientsList $clients -color "White"

    # Status des Clients aktualisieren
    Update-ClientStatus -client $client

    # Kurze Pause zwischen den Tests
    Start-Sleep 2
}

# Bildschirm leeren für die endgültige Ausgabe
Clear-Host

# Endgültige Ausgabe der Ergebnisse

# Anzeige der Online-Clients
$onlineClients = $clients | Where-Object { $_.Status -eq $Status.Online }
if ($onlineClients.Count -gt 0) {
    Display-ClientTable -clientsList $onlineClients -color "Green"
    Write-Host ""
}

# Anzeige der Offline-Clients
$offlineClients = $clients | Where-Object { $_.Status -eq $Status.Offline }
if ($offlineClients.Count -gt 0) {
    Display-ClientTable -clientsList $offlineClients -color "Red"
    Write-Host ""
}

# Anzeige der ausstehenden Clients
$pendingClients = $clients | Where-Object { $_.Status -eq $Status.Pending }
if ($pendingClients.Count -gt 0) {
    Display-ClientTable -clientsList $pendingClients -color "Yellow"
}
