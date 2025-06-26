function Write-WSUSLog {
    <#
    .SYNOPSIS
    Erstellt formatierte, farbige Log-Ausgaben mit Zeitstempel für WSUS-Operationen.
    
    .DESCRIPTION
    Erzeugt einheitliche Konsolen-Logs im Format: [HH:mm:ss] Nachricht
    Unterstützt verschiedene Status-Level mit automatischer Farbzuordnung.
    INLINE-Status geben nur Text ohne Zeitstempel aus.
    
    .PARAMETER Message
    Die auszugebende Nachricht.
    
    .PARAMETER Status
    Log-Level: INFO, SUBINFO, SUCCESS, WARNING, ERROR, DEBUG, INLINE_GREEN, INLINE_RED
    Standard: INFO
    
    .PARAMETER MessageColor
    Überschreibt die automatische Farbzuordnung.
    
    .PARAMETER NoNewLine
    Verhindert Zeilenumbruch nach der Ausgabe.
    
    .EXAMPLE
    Write-WSUSLog "WSUS-Server verbunden" -Status SUCCESS
    # [14:30:15] WSUS-Server verbunden (grün)
    
    .EXAMPLE
    Write-WSUSLog "Verarbeitung läuft..." -NoNewLine
    Write-WSUSLog " erfolgreich!" -Status INLINE_GREEN
    # [14:30:16] Verarbeitung läuft... erfolgreich!
    
    .EXAMPLE
    Write-WSUSLog "Detailinfo" -Status SUBINFO
    # [14:30:17] Detailinfo (dunkelgrau)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [ValidateSet("INFO", "SUBINFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "INLINE_GREEN", "INLINE_RED")]
        [string]$Status = "INFO",
        
        [ConsoleColor]$MessageColor,
        
        [switch]$NoNewLine
    )
    
    begin {
        # Farbzuordnung (einmalig definiert)
        $StatusColors = @{
            SUCCESS      = "Green"
            ERROR        = "Red"
            WARNING      = "Yellow"
            INFO         = "White"
            SUBINFO      = "DarkGray"
            DEBUG        = "Magenta"
            INLINE_GREEN = "Green"
            INLINE_RED   = "Red"
        }
        
        $InlineStatus = @("INLINE_GREEN", "INLINE_RED")
    }
    
    process {
        # Farbbestimmung
        $Color = if ($MessageColor) { $MessageColor } else { $StatusColors[$Status] }
        
        # INLINE-Status: Nur Text ohne Zeitstempel
        if ($Status -in $InlineStatus) {
            Write-Host $Message -NoNewline:$NoNewLine -ForegroundColor $Color
            return
        }
        
        # Standard-Ausgabe: [Zeitstempel] Nachricht
        $TimeStamp = Get-Date -Format "HH:mm:ss"
        
        Write-Host "[" -NoNewline -ForegroundColor White
        Write-Host $TimeStamp -NoNewline
        Write-Host "] " -NoNewline -ForegroundColor White
        Write-Host $Message -NoNewline:$NoNewLine -ForegroundColor $Color
    }
}
