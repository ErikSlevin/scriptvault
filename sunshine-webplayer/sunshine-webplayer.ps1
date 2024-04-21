#
# Ersteller: ErikSlevin
# Erstellungsdatum: 21. April 2024
#
# Dieses PowerShell-Skript durchsucht die Webseite von Sunshine Live, extrahiert die Titel und Links der verfügbaren Streams,
# sortiert sie alphabetisch und erstellt dann eine HTML-Datei mit einem Audioplayer und Buttons zum Abspielen der Streams.
# Alle Streams kommen direkt von Sunshine Live.

# URL der Website
$url = "https://stream.sunshine-live.de/"

# Dateipfad zum Speichern der HTML-Datei
$dateiPfad = "C:/Users/erik/Desktop/sunshine-live.html"

# Webseite herunterladen
$response = Invoke-WebRequest -Uri $url

# HTML-Inhalt der Webseite
$htmlContent = $response.Content

# Regulärer Ausdruck, um den Titel und den ersten Link innerhalb jedes <div>-Elements mit der Klasse "wrapper" zu finden
$regex = '(?s)<div class="wrapper">.*?<h1>(.*?)<\/h1>.*?<p class="linkstreamurl"><a href="([^"]+)"'

# Alle Übereinstimmungen finden
$matches = [regex]::Matches($htmlContent, $regex)

# Extrahierte Titel und Links speichern
$streamData = @()
$streamData += [PSCustomObject]@{
    Title = "Live On Air"
    Link = "http://stream.sunshine-live.de/live/mp3-192"
}

# Durch alle Übereinstimmungen iterieren und Titel und ersten Link pro <div class="wrapper"> extrahieren
foreach ($match in $matches) {
    # Extrahiere Titel und Link
    $title = $match.Groups[1].Value -replace '(?i)sunshine live - ', '' -replace '(?i)Die 80er', '80er' -replace "'n'", "&"
    $link = $match.Groups[2].Value
    
    # Füge ein neues PSCustomObject zum $streamData-Array hinzu
    $streamData += [PSCustomObject]@{
        Title = $title
        Link = $link
    }
}

# Sortieren der Streamdaten nach dem Titel (nach A bis Z)
$streamData = $streamData | Sort-Object { $_.Title -replace '[^\w\s]', '' }

# Den ersten Eintrag auswählen
$firstStream = $streamData[0]

# Audio-Quelle setzen
$audioSource = $firstStream.Link

# HTML-Datei erstellen
$html = @"
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sunshine Live Streams</title>
  <!-- Bootstrap CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
  <style>
        .music-player {
            text-align: center;
            margin: 20px auto;
        }

        footer {
            position: fixed;
            left: 0;
            bottom: 0;
            width: 100%;
            background-color: red;
            color: white;
            text-align: center;
        }
  </style>
</head>
<body>

<div class="container mt-5">
  <h1 class="text-center mb-4">Sunshine Live Streams</h1>
  <!-- Titel des aktuell abgespielten Streams -->
  <h2 id="streamTitle" class="text-center mb-4">[TITLE]</h2>
  <div class="row">
    <div class="col-md-12 text-center">
      <!-- Audioplayer -->
      <audio controls autoplay id="audioPlayer" class="w-20" controlsList="nodownload noplaybackrate" src="$($streamData[0].Link)"></audio>
    </div>
    <div class="col-md-12 mt-3 text-center">
"@

# Buttons für jeden Stream hinzufügen
$html += @"
<!-- Button zum Abspielen des Streams -->
<button type="button" class="btn btn-outline-danger btn-sm mb-1" onclick="playStream('http://stream.sunshine-live.de/live/mp3-192', this, 'Live On Air')">Live On Air</button>
"@

foreach ($stream in $streamData) {
    # Überprüfen, ob der aktuelle Stream nicht "Live On Air" ist, um ihn hinzuzufügen
    if ($stream.Title -ne "Live On Air") {
        $html += @"
           <!-- Button zum Abspielen des Streams -->
           <button type="button" class="btn btn-outline-primary btn-sm mb-1" onclick="playStream('$($stream.Link)', this, '$($stream.Title)')">$($stream.Title)</button>
"@
    }
}

# Restliche HTML-Struktur hinzufügen
$html += @"
   </div>
  </div>
</div>

<footer class="footer mt-auto py-3 bg-light">
  <div class="container">
    <!-- Footer-Text -->
    <span class="text-muted" style="font-size: 12px;">Made with <span style="color: #e25555;">❤</span> by ErikSlevin - Playlists bereitgestellt von Sunshine Live: <a href="https://www.sunshine-live.de/">www.sunshine-live.de</a></span>
  </div>
</footer>

<!-- Bootstrap JS -->
<script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.6/dist/umd/popper.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.min.js"></script>

<!-- JavaScript zum Steuern des Audioplayers und der Stream-Auswahl -->
<script>
  function playStream(url, button, title) {
    var audioPlayer = document.getElementById('audioPlayer');
    audioPlayer.src = url;

    // Alle Buttons zurücksetzen
    var allButtons = document.querySelectorAll('.btn');
    allButtons.forEach(function(btn) {
      btn.classList.remove('btn-primary', 'active');
      btn.classList.add('btn-outline-primary');
    });

    // Angeklickten Button als aktiv markieren
    button.classList.remove('btn-outline-primary');
    button.classList.add('btn-primary', 'active');

    // Stream-Titel aktualisieren
    document.getElementById('streamTitle').textContent = title;
  }

  // Live-Kanal automatisch abspielen und Button als aktiv markieren beim Laden der Seite
  window.onload = function() {
    var liveButton = document.querySelector('.btn-danger'); // Der Live On Air Button
    var liveButtonTitle = liveButton.textContent.trim(); // Titel des Live On Air Buttons
    var liveButtonUrl = liveButton.getAttribute('onclick').match(/'(.*?)'/)[1]; // URL des Live On Air Streams
    playStream(liveButtonUrl, liveButton, liveButtonTitle);
  };
</script>

</body>
</html>
"@

# HTML-Datei speichern
$html | Out-File -FilePath $dateiPfad -Encoding UTF8
