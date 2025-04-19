Get-VM | Where-Object { $_.Name -like "VM PROD*" } | ForEach-Object {
    $vm = $_
    $nic = Get-VMNetworkAdapter -VMName $vm.Name
    if ($nic) {
        Set-VMNetworkAdapter -VMName $vm.Name -Name $nic.Name -IPsecOffloadMaximumSecurityAssociation 1
        Write-Host -ForegroundColor Green "IPSec Task aktiviert: $($vm.Name)" 
    } else {
        Write-Host -ForegroundColor Red "IPSec Task konnte nicht aktiviert werden: $($vm.Name), Netzwerkkarte nicht gefunden"
    }
}
