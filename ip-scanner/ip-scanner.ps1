# Benutzer auffordern, Start- und End-IP-Adresse einzugeben
$startIPString = "10.0.0.0"
$endIPString = "10.0.0.90"

$StartTime = $(get-date -Format u)
# Konvertieren Sie die IP-Adressen in ein numerisches Format
$startIPNum = [System.Net.IPAddress]::Parse($startIPString).GetAddressBytes()
$endIPNum = [System.Net.IPAddress]::Parse($endIPString).GetAddressBytes()

$l = 1
$totalIPs = (($endIPNum[0] - $startIPNum[0]) * 256 + ($endIPNum[1] - $startIPNum[1]) * 256 + ($endIPNum[2] - $startIPNum[2]) * 256 + ($endIPNum[3] - $startIPNum[3])) + 1
$wertigkeit = [math]::Ceiling([math]::Log10($totalIPs))
$foundIPs = @()
$filePath ="$env:USERPROFILE\Desktop\$startIPString-$endIPString-Results.log"
New-Item -Path $filePath -ItemType File -Force |Out-Null
$currentIPNum = $startIPNum

Clear-Host

while ($currentIPNum[0] -le $endIPNum[0] -and 
       $currentIPNum[1] -le $endIPNum[1] -and 
       $currentIPNum[2] -le $endIPNum[2] -and 
       $currentIPNum[3] -le $endIPNum[3]) {
    $currentIP = [System.Net.IPAddress]::new($currentIPNum)
    
    $message = ""    
    $zahlMitNullen = "{0:d$($wertigkeit)}" -f $l

   # Prüfen Sie, ob der Host erreichbar ist, indem Sie versuchen, ihn zu pingen
    if (Test-Connection -ComputerName $currentIP.ToString() -Count 1 -Quiet) {
        $message += $currentIP.ToString()

        # Ermitteln Sie die MAC-Adresse des gefundenen Hosts
        $macAddress = (Get-NetNeighbor -IPAddress $currentIP.ToString() -ErrorAction SilentlyContinue).LinkLayerAddress 
        if ($macAddress) {
            $message += "   $macAddress"
        }
        
        try {
            # Auflösen des Hostnamens für die gefundene IP-Adresse
            $hostName = [System.Net.Dns]::GetHostEntry($currentIP).HostName
            $message += "   $hostName"
        }
        catch {
            # Unterdrücken Sie den Fehler, wenn der Hostname nicht gefunden werden kann
            $hostName = ""
        }
        
        # Schreiben Sie den gefundenen Host, Hostnamen und MAC-Adresse in die Log-Datei
        $logEntry = "[$($currentIP.ToString())]`t[$macAddress]`t[$hostName]" 
        $zahlMitNullen = "{0:d$($wertigkeit)}" -f $l
        Write-Host -ForegroundColor Green "   [$($zahlMitNullen) von $($totalIPs)]   $($message)"
        $foundIPs += $message
        Add-Content -Path $filePath -Value $logEntry

    } else {
        # Zeigen Sie an, welche IP-Adresse gerade gescannt wird
        Write-Host -ForegroundColor DarkGray "   [$($zahlMitNullen) von $($totalIPs)]   $($currentIP.ToString())"
    }
    $l++


    # Inkrementieren Sie die IP-Adresse um 1
    $currentIPNum[3]++
    
    if ($currentIPNum[3] -gt 254) {
        $currentIPNum[2]++
        $currentIPNum[3] = 0
        
        if ($currentIPNum[2] -gt 254) {
            $currentIPNum[1]++
            $currentIPNum[2] = 0
            
            if ($currentIPNum[1] -gt 254) {
                $currentIPNum[0]++
                $currentIPNum[1] = 0
            }
        }
    }
}

Write-Host ""
Write-Host -ForegroundColor Green "       " $foundIPs.Count "IP-Adressen gefunden!"
Write-Host "_______________________________________"
Write-Host ""
Write-Host "     Beginn: $StartTime"
Write-Host ""
for ($i = 1; $i -lt $foundIPs.Count; $i++) {
    Write-Host "  [$i]  - " $foundIPs[$i]
}
Write-Host ""
Write-Host "     Ende:  $(get-date -Format u)"
Write-Host "---------------------------------------"
Write-Host "Log-File gespeichert unter: $filePath"
Write-Host ""