# Funktion zum Senden des WOL-Pakets
function SendeWOLPaket {
    param (
        [Parameter(Mandatory=$true)]
        [string]$MACAdresse,                        # Die MAC-Adresse des Zielcomputers
        [string]$BroadcastAdresse = "10.0.0.255",   # Die Broadcast-Adresse im Netzwerk
        [int]$Port = 9                              # Der Port für das WOL-Paket (Standard: 9)
    )
    
    # MAC-Adresse in Byte-Array konvertieren
    $MACBytes = $MACAdresse -split '[:-]' | ForEach-Object { [byte]('0x' + $_) }

    # WOL-Paket erstellen
    $Paket = (,0xFF * 6) + ($MACBytes * 16)

    # UDP-Client erstellen und verbinden
    $UDPClient = New-Object System.Net.Sockets.UdpClient
    $UDPClient.Connect(([System.Net.IPAddress]::Parse($BroadcastAdresse)), $Port)

    # Paket senden
    $UDPClient.Send($Paket, $Paket.Length)

    # Verbindung schließen
    $UDPClient.Close()
}

# Funktion zum Herstellen einer RDP-Verbindung mit Verzögerung
function VerbindeMitRDP {
    param (
        [Parameter(Mandatory=$true)]
        [string]$rdpDatei,                 # Der Pfad zur RDP-Datei
        [string]$ziel,                     # Die IP-Adresse oder der Hostname des Zielcomputers
        [int]$Verzoegerung = 60            # Die Verzögerung vor der RDP-Verbindung (Standard: 60 Sekunden)
    )

    # Timer starten
    for ($i = $Verzoegerung; $i -ge 0; $i--) {
        Write-Host "Verbleibende Zeit bis zur RDP-Verbindung: $i Sekunden"
        Start-Sleep -Seconds 1
    }

    # RDP-Verbindung herstellen
    mstsc $rdpDatei /f /v:$ziel
}

# MAC-Adresse des Ziels
$MACAdresse = "D8:BB:C1:D0:10:BB"  # Hier die MAC-Adresse des Zielcomputers eintragen

# Funktion aufrufen, um das WOL-Paket zu senden
SendeWOLPaket -MACAdresse $MACAdresse

# IP-Adresse des Ziels
$zielIP = "10.0.0.100"
# Pfad zur RDP-Datei
$rdpDatei = "C:\Users\erikw\OneDrive\05 - Sonstiges\workstation.rdp"

# RDP-Verbindung herstellen
VerbindeMitRDP -rdpDatei $rdpDatei -ziel $zielIP
