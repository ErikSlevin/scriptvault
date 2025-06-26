function Connect-WSUSServer {
    <#
    .SYNOPSIS
    Stellt eine Verbindung zum WSUS-Server her - lokal oder domänenbasiert.
    
    .DESCRIPTION
    Verbindet sich mit dem WSUS-Server basierend auf der gewählten Konfiguration:
    - LOCAL: Lokaler Server ohne SSL (Port 8530)
    - DOMAIN: Domänen-Server mit SSL (Port 8531)
    
    .PARAMETER Mode
    Verbindungsmodus: LOCAL oder DOMAIN
    Standard: LOCAL
    
    .PARAMETER ServerName
    Optionaler Server-Name (überschreibt automatische Erkennung)
    
    .PARAMETER Port
    Optionaler Port (überschreibt Standard-Ports)
    
    .PARAMETER UseSSL
    Optionale SSL-Einstellung (überschreibt Standard-SSL-Konfiguration)
    
    .OUTPUTS
    Microsoft.UpdateServices.Administration.IUpdateServer
    WSUS-Server-Objekt bei erfolgreicher Verbindung
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode LOCAL
    # Verbindet zu lokalem WSUS ohne SSL auf Port 8530
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode DOMAIN
    # Verbindet zu Domänen-WSUS mit SSL auf Port 8531
    
    .EXAMPLE
    $WSUSServer = Connect-WSUSServer -Mode DOMAIN -ServerName "wsus.firma.local"
    # Verbindet zu spezifischem Domänen-Server
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("LOCAL", "DOMAIN")]
        [string]$Mode = "LOCAL",
        
        [Parameter(Mandatory = $false)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [bool]$UseSSL
    )
    
    begin {
        # WSUS-Assembly laden
        try {
            Add-Type -Path "${env:ProgramFiles}\Update Services\Api\Microsoft.UpdateServices.Administration.dll" -ErrorAction Stop
        }
        catch {
            Write-WSUSLog "Fehler beim Laden der WSUS-Assembly: $($_.Exception.Message)" -Status ERROR
            throw "WSUS-Assembly konnte nicht geladen werden. Ist WSUS installiert?"
        }
    }
    
    process {
        try {
            # Konfiguration basierend auf Modus bestimmen
            switch ($Mode.ToUpper()) {
                "LOCAL" {
                    $ComputedServerName = if ($ServerName) { $ServerName } else { $env:COMPUTERNAME }
                    $ComputedUseSSL = if ($PSBoundParameters.ContainsKey('UseSSL')) { $UseSSL } else { $false }
                    $ComputedPort = if ($Port) { $Port } else { 8530 }
                }
                
                "DOMAIN" {
                    if ($ServerName) {
                        $ComputedServerName = $ServerName
                    } else {
                        if (-not $env:USERDNSDOMAIN) {
                            throw "Domäne konnte nicht ermittelt werden. Bitte ServerName-Parameter verwenden."
                        }
                        $ComputedServerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
                    }
                    
                    $ComputedUseSSL = if ($PSBoundParameters.ContainsKey('UseSSL')) { $UseSSL } else { $true }
                    $ComputedPort = if ($Port) { $Port } else { 8531 }
                }
            }
            
            
            $WSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer(
                $ComputedServerName,
                $ComputedUseSSL,
                $ComputedPort
            )        
            # Verbindungsdetails anzeigen
            Write-WSUSLog "WSUS-Verbindung erfolgreich hergestellt" -Status SUCCESS

            
            return $WSUSServer

        }
        catch {
            Write-WSUSLog "Fehler bei WSUS-Verbindung: $($_.Exception.Message)" -Status ERROR
            Write-WSUSLog "Server: $ComputedServerName | SSL: $ComputedUseSSL | Port: $ComputedPort"  -Status ERROR
        }
    }
}
