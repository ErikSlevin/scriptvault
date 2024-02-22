Start-Transcript -Path "C:\Users\[USER]\skripte\logs\$(Get-Date -Format "yyyy-MM-dd-HH-mm")_download-autodelete.log"
try{
    $Pfad = "C:\Users\[USER]\Downloads\"
    $CSV = "C:\Users\[USER]\skripte\logs\download-autodelete.csv"
    $Datum = Get-Date -Format "dd.MM.yyyy"
    $Uhrzeit = "$(Get-Date -Format "HH:mm") Uhr"
    if (Test-Path -Path $Pfad){
        
        $Inhalt = Get-FolderSize -BasePath $Pfad | Select-Object @{ l='Datum'; e={ $Datum} },@{ l='Uhrzeit'; e={ $Uhrzeit} },@{l = "Datei"; e={$_.FolderName}},@{l = "Dateigröße"; e={$_.SizeMB}}
        if (Test-Path $CSV -PathType leaf){
            $Inhalt | Export-CSV -Append $CSV -Encoding UTF8 -Delimiter ';'
        } else {
            $Inhalt | Export-CSV $CSV -Encoding UTF8 -Delimiter ';'
        }
        
        Remove-Item $Pfad* -Recurse -Force
    } 
}
catch{
    Write-Host "$($Datum) | $($Uhrzeit) | $($_.Exception.Message)"
    
}
finally{
    Write-Host "$($Datum) | $($Uhrzeit) | Download Autoclean erfolgreich ausgeführt!"
}
Stop-Transcript
