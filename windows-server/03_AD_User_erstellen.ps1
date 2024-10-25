#--------------------------------#
#         AD-USER  ERSTELLEN     #
#--------------------------------#

#--------------------------------#
#         AD-USER  ERSTELLEN     #
#--------------------------------#


# $DomainName = pod03.spielwiese.intern
$DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain

Clear-Host
Write-Host ""
Write-Host -ForegroundColor Green $DomainName
Write-Host ""
$confirmation = Read-Host "Der FQDN der Domain istr ichtig? (Ja/Nein)"

if ($confirmation -ne "Ja") {
    Write-Host "Das Skript wird beendet."
    return
}

$users = @(
    'Maximilian Müller',
    'Sophie Roffel',
    'John Günter',
    'Emily Kranz',
    'Lukas Krazewtzki',
    'Anna Seelenburg',
    'Michael Wagner',
    'Laura Bäcker',
    'Tim Hoffmann',
    'Julia Lipktus'
)

# Domain-Variable

$userObjects = @()
$heutigesDatum = Get-Date -Format "dd.MM.yyyy"
function Remove-SpecialCharacters {
    param ($inputString)
    $outputString = $inputString
    $outputString = $outputString -replace 'ä', 'ae'
    $outputString = $outputString -replace 'ö', 'oe'
    $outputString = $outputString -replace 'ü', 'ue'
    $outputString = $outputString -replace 'ß', 'ss'
    $outputString = $outputString -replace '[^a-zA-Z0-9]', ''
    return $outputString
}

foreach ($name in $users) {
    $splitName = $name -split ' '
    $vorname = $splitName[0]
    $nachname = $splitName[1]
    $vornameClean = Remove-SpecialCharacters $vorname
    $nachnameClean = Remove-SpecialCharacters $nachname
    $samAccountName = ($vornameClean.Substring(0,1) + $nachnameClean).ToLower()
    $userPrincipalName = "$samAccountName@$DomainName"
    $userObjects += [PSCustomObject]@{
        Vorname            = $vorname
        Nachname           = $nachname
        SamAccountName     = $samAccountName
        UserPrincipalName  = $userPrincipalName
        Name               = $samAccountName
        DisplayName        = "$vornameClean $nachnameClean"
        EmailAddress       = $userPrincipalName
        Description        = "Erstellt am " + $heutigesDatum
    }
}

$userObjects | Format-Table
$confirmation = Read-Host "Möchtest du die angezeigten Benutzer in der Domain '$DomainName' erstellen? (Ja/Nein)"

if ($confirmation -eq "Ja") {
    foreach ($user in $userObjects) {
        try {
            $password = ConvertTo-SecureString "Passw0rd" -AsPlainText -Force
            New-ADUser -SamAccountName $user.SamAccountName `
                       -UserPrincipalName $user.UserPrincipalName `
                       -Name $user.DisplayName `
                       -GivenName $user.Vorname `
                       -Surname $user.Nachname `
                       -DisplayName $user.DisplayName `
                       -EmailAddress $user.EmailAddress `
                       -Description $user.Description `
                       -Enabled $true `
                       -AccountPassword $password `
                       -PasswordNeverExpires $false `
                       -PassThru | Out-Null
            Write-Host -ForegroundColor Green "$($user.DisplayName) ($($user.SamAccountName)) erstellt."
        } catch {
            Write-Host -ForegroundColor Red "Fehler: $($user.DisplayName): $_"
        }
    }
} else {
    Write-Host "Keine Benutzer wurden erstellt."
}

