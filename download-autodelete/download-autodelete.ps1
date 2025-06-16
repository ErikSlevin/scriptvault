<#
.SYNOPSIS
    Automatische Bereinigung des Downloads-Ordners mit Windows-Aufgabenplanung

.DESCRIPTION
    Dieses PowerShell-Script installiert sich selbst als Windows-Aufgabe und bereinigt
    automatisch den Downloads-Ordner von Dateien und Ordnern, die älter als 48 Stunden sind.
    
    Features:
    - Selbstinstallation als geplante Windows-Aufgabe
    - Stündliche automatische Überprüfung (läuft unendlich)
    - Löscht nur Dateien/Ordner älter als 48 Stunden
    - Detaillierte Protokollierung in Log-Datei
    - Robuste Fehlerbehandlung
    - Status-Check für bereits installierte Aufgaben

.PARAMETER Install
    Installiert die geplante Windows-Aufgabe für automatische stündliche Bereinigung

.PARAMETER Cleanup
    Führt einmalig die Bereinigung des Downloads-Ordners durch

.EXAMPLE
    .\Downloads-Cleanup.ps1 -Install
    Installiert die geplante Aufgabe, die stündlich automatisch läuft

.EXAMPLE
    .\Downloads-Cleanup.ps1 -Cleanup
    Führt sofort eine einmalige Bereinigung durch

.EXAMPLE
    .\Downloads-Cleanup.ps1
    Zeigt Status der installierten Aufgabe und Hilfe-Informationen

.NOTES
    Autor: Erik Selvin
    Version: 0.6
    Erstellt: 16.06.20255
    
    Log-Datei: $env:USERPROFILE\Downloads_Cleanup.log
    Zeitlimit: 48 Stunden
    Intervall: 1 Stunde

.LINK
    GitHub: https://github.com/ErikSlevin/scriptvault/blob/main/download-autodelete/download-autodelete.ps1
#>

param(
    [switch]$Install,  # Installiert die geplante Aufgabe
    [switch]$Cleanup   # Führt die Bereinigung durch
)

# Konfiguration
$DownloadsPath = "$env:USERPROFILE\Downloads"
$TimeLimit = (Get-Date).AddHours(-48)
$LogPath = "$env:USERPROFILE\Downloads_Cleanup.log"
$TaskName = "Downloads-Cleanup-Hourly"
$ScriptPath = $PSCommandPath  # Pfad zu diesem Script

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Add-Content -Path $LogPath
}

function Install-ScheduledTask {
    try {
        Write-Host "Prüfe geplante Aufgabe..." -ForegroundColor Yellow
        
        # Prüfe ob Aufgabe bereits existiert
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Write-Host "Aufgabe '$TaskName' existiert bereits!" -ForegroundColor Green
            Write-Host "Status: $($ExistingTask.State)" -ForegroundColor Cyan
            return
        }
        
        Write-Host "Erstelle geplante Aufgabe..." -ForegroundColor Yellow
        
        # Erstelle Principal (Benutzerkontext)
        $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
        
        # Erstelle Trigger (stündlich ausführen - unendlich)
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1)
        
        # Erstelle Aktion (dieses Script mit -Cleanup Parameter aufrufen)
        $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" -Cleanup"
        
        # Erstelle Einstellungen
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        
        # Registriere die geplante Aufgabe
        Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -Settings $Settings -Principal $Principal -Description "Löscht Downloads älter als 48 Stunden"
        
        Write-Host "Geplante Aufgabe '$TaskName' wurde erfolgreich erstellt!" -ForegroundColor Green
        Write-Host "Die Aufgabe startet in 2 Minuten und läuft dann stündlich." -ForegroundColor Green
        
        # Zeige Aufgaben-Details
        Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, LastRunTime, NextRunTime | Format-List
        
    } catch {
        Write-Host "FEHLER beim Erstellen der geplanten Aufgabe: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-Cleanup {
    try {
        Write-Log "Cleanup-Prozess gestartet"
        
        # Überprüfe, ob Downloads-Ordner existiert
        if (-not (Test-Path $DownloadsPath)) {
            Write-Log "WARNUNG: Downloads-Ordner nicht gefunden: $DownloadsPath"
            return
        }
        
        # Finde alle Dateien und Ordner älter als 48 Stunden
        $ItemsToDelete = Get-ChildItem -Path $DownloadsPath -Recurse | 
                         Where-Object { $_.LastWriteTime -lt $TimeLimit }
        
        if ($ItemsToDelete.Count -eq 0) {
            Write-Log "Keine Dateien älter als 48 Stunden gefunden"
            return
        }
        
        Write-Log "Gefunden: $($ItemsToDelete.Count) Elemente zum Löschen"
        
        # Lösche gefundene Elemente
        foreach ($Item in $ItemsToDelete) {
            try {
                if ($Item.PSIsContainer) {
                    # Ordner löschen
                    Remove-Item -Path $Item.FullName -Recurse -Force
                    Write-Log "Ordner gelöscht: $($Item.FullName)"
                } else {
                    # Datei löschen
                    Remove-Item -Path $Item.FullName -Force
                    Write-Log "Datei gelöscht: $($Item.FullName)"
                }
            }
            catch {
                Write-Log "FEHLER beim Löschen von $($Item.FullName): $($_.Exception.Message)"
            }
        }
        
        Write-Log "Cleanup-Prozess abgeschlossen"
        
    } catch {
        Write-Log "KRITISCHER FEHLER: $($_.Exception.Message)"
    }
}

# Hauptlogik
if ($Install) {
    Install-ScheduledTask
}
elseif ($Cleanup) {
    Start-Cleanup
}
else {
    # Kein Parameter gegeben - zeige Hilfe
    Write-Host "Downloads-Cleanup Script" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Verwendung:" -ForegroundColor Yellow
    Write-Host "  .\Downloads-Cleanup.ps1 -Install   # Installiert die geplante Aufgabe" -ForegroundColor White
    Write-Host "  .\Downloads-Cleanup.ps1 -Cleanup   # Führt einmalig die Bereinigung durch" -ForegroundColor White
    Write-Host ""
    Write-Host "Die geplante Aufgabe löscht automatisch stündlich alle Downloads älter als 48h." -ForegroundColor Green
    Write-Host ""
    
    # Prüfe ob Aufgabe bereits installiert ist
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Host "Status: Aufgabe ist bereits installiert ✓" -ForegroundColor Green
        Write-Host "Letzter Lauf: $($ExistingTask.LastRunTime)" -ForegroundColor Cyan
        Write-Host "Nächster Lauf: $($ExistingTask.NextRunTime)" -ForegroundColor Cyan
    } else {
        Write-Host "Status: Aufgabe ist noch nicht installiert" -ForegroundColor Red
        Write-Host "Führe 'Downloads-Cleanup.ps1 -Install' aus, um sie zu installieren." -ForegroundColor Yellow
    }
}
