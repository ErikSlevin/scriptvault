# Definiere ein 2D-Array mit den Paketnamen und IDs, alphabetisch sortiert
$applications = @(
    @("3D Connetion","3Dconnexion.3DxWare.10")                  # 3D Connection
    @("7-Zip", "7zip.7zip"),                                    # 7-Zip
    @("Bambu Studio", "Bambulab.Bambustudio"),                  # Bambu Studio
    @("Bitwarden", "Bitwarden.Bitwarden"),                      # Bitwarden
    @("Bitwarden CLI", "Bitwarden.CLI"),                        # Bitwarden CLI
    @("Discord", "Discord.Discord"),                            # Discord
    @("Epic Games Launcher", "EpicGames.EpicGamesLauncher"),    # Epic Games Launcher
    @("GitHub Desktop", "GitHub.GitHubDesktop"),                # GitHub Desktop
    @("draw.io", "JGraph.Draw"),                                # draw.io
    @("EasyEDA", "JLC.EasyEDA"),                                # EasyEDA
    @("Logitech G HUB", "Logitech.GHUB"),                       # Logitech G HUB
    @("Microsoft Office", "Microsoft.Office"),                  # Microsoft Office
    @("PowerToys", "Microsoft.PowerToys"),                      # PowerToys
    @("Visual Studio Code", "Microsoft.VisualStudioCode"),      # Visual Studio Code
    @("Windows Terminal", "Microsoft.WindowsTerminal"),         # Windows Terminal
    @("GeForce Experience", "Nvidia.GeForceExperience"),        # GeForce Experience
    @("OBS Studio", "OBSProject.OBSStudio"),                    # OBS Studio
    @("FileBot", "PointPlanck.FileBot"),                        # FileBot
    @("WinRAR", "RARLab.WinRAR"),                               # WinRAR
    @("HWiNFO", "REALiX.HWiNFO"),                               # HWiNFO
    @("Spotify", "Spotify.Spotify"),                            # Spotify
    @("TeamViewer", "TeamViewer.TeamViewer"),                   # TeamViewer
    @("Steam", "Valve.Steam"),                                  # Steam
    @("VLC Media Player", "VideoLAN.VLC"),                      # VLC Media Player
    @("WireGuard", "WireGuard.WireGuard"),                      # WireGuard
    @("WhatsApp", "9NKSQGP7F2NH"),                              # WhatsApp
    @("PDF24 Creator", "geeksoftwareGmbH.PDF24Creator")         # PDF24 Creator
)

# ANSI Escape Code für grünen Text
$green = "`e[32m"
$reset = "`e[0m"

# Gesamte Anzahl der Pakete
$totalPackages = $applications.Length
$installedPackages = @()

# Gehe das Array durch und installiere jedes Paket mit winget
for ($i = 0; $i -lt $totalPackages; $i++) {
    $appName = $applications[$i][0]
    $appId = $applications[$i][1]
    $currentPackageNumber = $i + 1
    $progress = [math]::Round(($currentPackageNumber / $totalPackages) * 100)

    # Ausgabe der aktuellen Installation
    Write-Host "Aktuelle Installation: $appName"
    Write-Host "Paket $currentPackageNumber von $totalPackages"
    Write-Host "Gesamtfortschritt: $progress%"
    Write-Host ""

    # Versuche, das Paket zu installieren und fange mögliche Fehler ab
    try {
        winget install --id $appId -h --accept-package-agreements --accept-source-agreements
        # Paket als installiert markieren
        $installedPackages += "$appName installiert ${green}✓${reset}"
    } catch {
        Write-Host "Fehler beim Installieren von $appName ($appId): $_"
    }

    # Terminal löschen und den Installationsstatus ausgeben
    Clear-Host
    $installedPackages | ForEach-Object { Write-Host $_ }
}
