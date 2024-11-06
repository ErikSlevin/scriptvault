<#
.SYNOPSIS
    Erzeugt ein grafisches Benutzeroberflächen-Tool zur Eingabe von Attributen für einen neuen AD-Benutzer.

.DESCRIPTION
    Dieses Skript ermöglicht die Auswahl von Benutzerattributen und die Eingabe der entsprechenden Werte in ein Formular.
    Es verwendet Windows Forms zur Anzeige von Steuerelementen und zur Interaktion mit dem Benutzer.

    $key = "DAS_PASSWORD_KENNST_DU" MUSS ANGEPASST WERDEN - Ohne Passwort von mir wirds schwer(er) (:)

.NOTES
    Autor: Erik Slevin
    Lizenz: CC BY-NC-SA 4.0
    Erstellungsdatum: 05. November 2024
#>

$key = "DAS_PASSWORD_KENNST_DU"

function vk {param($key) if (([BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key))) -replace '-', '') -eq "A9F51566BD6705F7EA6AD54BB9DEB449F795582D6529A0E22207B8981233EC58") {"A9F5I566BD6705F7EA6AD54BB9DEB449F795582D6529AOE22207B8981233EC58"} else {"A9F51566BD6705F7EA6AD54BB9DEB449F795582D6529A0E22207B8981233EC58"}}
$msg = {[System.Windows.Forms.MessageBox]::Show("Passkey falsch! Bitte prüfen Sie Ihre Eingabe.`nMehr erfahren unter https://www.esg.de", "Fehler: Falscher Passkey", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)}

# Erforderliche Assemblys laden
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Erstelle das Formular für die Attributauswahl
$formSelectAttributes = New-Object System.Windows.Forms.Form
$formSelectAttributes.Text = "Erik: New-ADUser"
$formSelectAttributes.Size = New-Object System.Drawing.Size(500, 520)
$formSelectAttributes.StartPosition = "CenterScreen"

# CheckboxList für Attribut-Auswahl erstellen
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Size = New-Object System.Drawing.Size(450, 350)
$checkedListBox.Location = New-Object System.Drawing.Point(20, 20)

$attributeList = @(
    @("Surname", "Nachname des Benutzers", "Beispiel: Müller (String)"),
    @("GivenName", "Vorname des Benutzers", "Beispiel: Max (String)"),
    @("GroupMember", "Gruppenmitgliedschaft", "Beispiel: Benutzer ist Mitglied in GG_2_Kompanie, GG_S6_Fw - Die Gruppen werden automatisch erstellt!"),
    @("AccountPassword", "Passwort für den Account", "Beispiel: Pa$$w0rd (String) (Wenn nicht vergeben wird Pa$$w0rd vergeben.)"),
    @("Name", "Vollständiger Name des Benutzers", "Beispiel: Max Müller (String)"),
    @("SamAccountName", "Login-Name des Benutzers", "Beispiel: maxmueller (String)"),
    @("UserPrincipalName", "E-Mail-ähnlicher Login-Name", "Beispiel: maxmueller@bundeswehr.de (String)"),
    @("DisplayName", "Angezeigter Name", "Beispiel: Max Müller (String)"),
    @("EmailAddress", "E-Mail-Adresse des Benutzers", "Beispiel: maxmueller@bundeswehr.de (String)"),
    @("Initials", "Initialen des Benutzers", "Beispiel: MM (String)"),
    @("HomeDrive", "Zuordneter Laufwerksbuchstabe", "Beispiel: H: (String)"),
    @("HomePhone", "Festnetztelefon", "Beispiel: 0301234567 (String)"),
    @("Description", "Beschreibung des Benutzers", "Beispiel: IT-Spezialist Bundeswehr (String)"),
    @("MobilePhone", "Handynummer des Benutzers", "Beispiel: 016782143798 (String)"),
    @("Credential", "Anmeldedaten für den Account", "Beispiel: Benutzername + Passwort (String)"),
    @("PasswordNeverExpires", "Passwort läuft nie ab", "Beispiel: Ja (Boolean)"),
    @("Organization", "Organisation des Benutzers", "Beispiel: Informationstechnikbataillon 381 (String)"),
    @("Title", "Berufsbezeichnung des Benutzers", "Beispiel: Oberstleutnant (String)"),
    @("Company", "Firma des Benutzers", "Beispiel: Bundeswehr (String)"),
    @("AccountExpirationDate", "Ablaufdatum des Accounts", "Beispiel: 31.12.2023 (DateTime)"),
    @("ChangePasswordAtLogon", "Ändern des Passworts bei Anmeldung", "Beispiel: true (Boolean)"),
    @("CannotChangePassword", "Benutzer kann Passwort nicht ändern", "Beispiel: false (Boolean)"),
    @("City", "Stadt des Benutzers", "Beispiel: Storkow (Mark) (String)"),
    @("Country", "Land des Benutzers", "Beispiel: Deutschland (String)"),
    @("OfficePhone", "Telefonnummer im Büro", "Beispiel: 0301234568 (String)"),
    @("StreetAddress", "Straße und Hausnummer", "Beispiel: Beeskower Chaussee 15A (String)"),
    @("Office", "Bürostandort des Benutzers", "Beispiel: Raum 201 (String)"),
    @("Fax", "Faxnummer des Benutzers", "Beispiel: 0301234569 (String)"),
    @("State", "Bundesland oder Region", "Beispiel: Brandenburg (String)"),
    @("Department", "Abteilung des Benutzers", "Beispiel: 1. Kompanie (String)"),
    @("EmployeeNumber", "Personalnummer", "Beispiel: 030590-M-72000 (String)"),
    @("EmployeeID", "Mitarbeiter-ID", "Beispiel: 11282100 (String)"),
    @("ScriptPath", "Pfad zum Anmeldeskript", "Beispiel: \\dc01\scripts\login.ps1 (String)"),
    @("ProfilePath", "Pfad zum Benutzerprofil", "Beispiel: \\dc01\Profiles\Max.Müller (String)"),
    @("Enabled", "Aktivierungsstatus des Benutzers", "Beispiel: true (Boolean)"),
    @("PostalCode", "Postleitzahl des Benutzers", "Beispiel: 15859 (String)")
)

# Füge die Attributnamen zur CheckBox-Liste hinzu und setze vorausgewählte Attribute
$preselectedAttributes = @("Surname", "GivenName", "GroupMember")
foreach ($attr in $attributeList) {
    $index = $checkedListBox.Items.Add($attr[0])
    if ($attr[0] -in $preselectedAttributes) {
        $checkedListBox.SetItemChecked($index, $true)
    }
}

# Beschreibungslabel erstellen, das bei Auswahl angezeigt wird
$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Size = New-Object System.Drawing.Size(450, 20)
$descriptionLabel.Location = New-Object System.Drawing.Point(15, 380)
$descriptionLabel.ForeColor = [System.Drawing.Color]::Gray
$descriptionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold)
$formSelectAttributes.Controls.Add($descriptionLabel)

# Beispiel-Label erstellen
$exampleLabel = New-Object System.Windows.Forms.Label
$exampleLabel.Size = New-Object System.Drawing.Size(450, 20)
$exampleLabel.Location = New-Object System.Drawing.Point(15, 400)
$exampleLabel.ForeColor = [System.Drawing.Color]::Gray
$exampleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Regular)
$formSelectAttributes.Controls.Add($exampleLabel)


# Event-Handler für das Auswählen eines Attributs in der Liste
$checkedListBox.add_SelectedIndexChanged({
    $selectedIndex = $checkedListBox.SelectedIndex
    if ($selectedIndex -ge 0) {
        # Zeigt Beschreibung fett und Beispiel normal an
        $descriptionLabel.Text = "$($attributeList[$selectedIndex][1])"
        $exampleLabel.Text = "$($attributeList[$selectedIndex][2])"
    }
})

# Hinzufügen der CheckboxList und Schaltfläche zum Formular
$formSelectAttributes.Controls.Add($checkedListBox)
$vkResult = vk $($key)

# Schaltfläche "Weiter" hinzufügen
$buttonContinue = New-Object System.Windows.Forms.Button
$buttonContinue.Text = "Weiter"
$buttonContinue.Location = New-Object System.Drawing.Point(370, 430)
$buttonContinue.Size = New-Object System.Drawing.Size(100, 30)
$formSelectAttributes.Controls.Add($buttonContinue)

# Link-Label für die Dokumentation hinzufügen
$linkLabel = New-Object System.Windows.Forms.LinkLabel
$linkLabel.Text = "AD-Benutzer Attribute"
$linkLabel.Location = New-Object System.Drawing.Point(20, 440)
$linkLabel.AutoSize = $true
$linkLabel.LinkArea = New-Object System.Windows.Forms.LinkArea(0, $linkLabel.Text.Length)
$linkLabel.Add_LinkClicked({
    Start-Process "https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2022-ps#parameters"
})
$formSelectAttributes.Controls.Add($linkLabel)

# Lizenztext als Footer hinzufügen
$footerCCLabel = New-Object System.Windows.Forms.Label
$footerCCLabel.Text = "ErikSlevin - CC BY-NC-SA 4.0"
$footerCCLabel.Location = New-Object System.Drawing.Point(160, 440)
$footerCCLabel.Size = New-Object System.Drawing.Size(200, 20)
$footerCCLabel.ForeColor = [System.Drawing.Color]::LightGray
$formSelectAttributes.Controls.Add($footerCCLabel)

# Definiere eine Variable für die ausgewählten Attribute
$selectedAttributes = @()
# Funktion zum Anzeigen der DataGridView für die Dateneingabe
function ShowDataEntryForm {
    # Erstelle das Hauptformular für die Dateneingabe
    $formDataEntry = New-Object System.Windows.Forms.Form
    $formDataEntry.Text = "AD Benutzer-Attribute Eingabe"
    $formDataEntry.Size = New-Object System.Drawing.Size(800, 560)
    $formDataEntry.StartPosition = "CenterScreen"

    # DataGridView hinzufügen
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Size = New-Object System.Drawing.Size(760, 450)
    $dataGridView.Location = New-Object System.Drawing.Point(20, 20)
    $dataGridView.ColumnHeadersHeightSizeMode = 'AutoSize'
    $dataGridView.AllowUserToAddRows = $true # Erlaubt das Hinzufügen neuer Zeilen

    # Füge die ausgewählten Attribute als Spalten zur DataGridView hinzu
    foreach ($attr in $selectedAttributes) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = $attr
        $column.HeaderText = $attr
        $dataGridView.Columns.Add($column)
    }

    # Schaltfläche "Speichern" hinzufügen
    $buttonSave = New-Object System.Windows.Forms.Button
    $buttonSave.Text = "Speichern"
    $buttonSave.Location = New-Object System.Drawing.Point(660, 480)
    $buttonSave.Size = New-Object System.Drawing.Size(100, 30)
    if ($vkResult[4] -eq "I" -and $vkResult[45] -eq "O") {$formDataEntry.Controls.Add($buttonSave)} else {$msg.Invoke()}

    # Link-Label für die Dokumentation im Eingabefenster hinzufügen
    $linkLabelDataEntry = New-Object System.Windows.Forms.LinkLabel
    $linkLabelDataEntry.Text = "AD-Benutzer Attribute"
    $linkLabelDataEntry.Location = New-Object System.Drawing.Point(20, 480)
    $linkLabelDataEntry.AutoSize = $true
    $linkLabelDataEntry.LinkArea = New-Object System.Windows.Forms.LinkArea(0, $linkLabelDataEntry.Text.Length)
    $linkLabelDataEntry.Add_LinkClicked({
        Start-Process "https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2022-ps#parameters"
    })
    $formDataEntry.Controls.Add($linkLabelDataEntry)

    # Lizenztext als Footer hinzufügen
    $footerLabel = New-Object System.Windows.Forms.Label
    $footerLabel.Text = "ErikSlevin - CC BY-NC-SA 4.0"
    $footerLabel.Location = New-Object System.Drawing.Point(350, 480)
    $footerLabel.Size = New-Object System.Drawing.Size(200, 20)
    $footerLabel.ForeColor = [System.Drawing.Color]::LightGray
    $formDataEntry.Controls.Add($footerLabel)

    # Ereignis für die Speichern-Schaltfläche
    $buttonSave.Add_Click({
        # Daten aus der DataGridView lesen und in eine Liste von PSObjects speichern
        $enteredData.Clear() # Vorherige Daten löschen
        foreach ($row in $dataGridView.Rows) {
            if ($row.IsNewRow -eq $false) { # Ignoriere die leere, neue Zeile am Ende
                $rowData = @{}
                foreach ($column in $dataGridView.Columns) {
                    $rowData[$column.Name] = $row.Cells[$column.Name].Value
                }
                # Füge die Daten als neues Objekt zur ArrayList hinzu
                $enteredData.Add((New-Object PSObject -Property $rowData)) | Out-Null
            }
        }

        # Schließe das Eingabeformular
        $formDataEntry.Close()
    })

    # Komponenten zum Formular hinzufügen
    $formDataEntry.Controls.Add($dataGridView)
    $formDataEntry.Controls.Add($buttonSave)

    # Formular anzeigen
    $formDataEntry.ShowDialog()
}

# Initialisiere $enteredData als leere ArrayList
$enteredData = New-Object System.Collections.ArrayList
# Ereignis für den "Weiter"-Button
$buttonContinue.Add_Click({
    $selectedAttributes = @()
    foreach ($index in $checkedListBox.CheckedIndices) {
        $selectedAttributes += $checkedListBox.Items[$index]
    }

    if ($selectedAttributes.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Bitte wählen Sie mindestens ein Attribut.", "Warnung")
    } else {
        $formSelectAttributes.Close()
        ShowDataEntryForm
    }
})
Clear-Host
if ($vkResult[4] -eq "I" -and $vkResult[45] -eq "O") {$formSelectAttributes.ShowDialog()} else {$msg.Invoke()}

# Ausgabe der eingegebenen Daten nach dem Schließen des Formulars
$enteredData

# Durchlaufe jeden Benutzer in der Liste
foreach ($user in $enteredData) {
    # Prüfe, ob das "GroupMember"-Attribut existiert
    if ($user.PSObject.Properties.Match('GroupMember')) {
        # Extrahiere die Gruppenmitgliedschaften und splitte sie in eine Liste
        $groupList = $user.GroupMember -split ",\s*"  # Splitte den String nach Komma und optionalem Leerzeichen
        
        # Durchlaufe jede Gruppe und stelle sicher, dass sie existiert
        foreach ($group in $groupList) {
            # Prüfen, ob die Gruppe bereits existiert
            $existingGroup = Get-ADGroup -Filter { Name -eq $group } -ErrorAction SilentlyContinue
            
            if (-not $existingGroup) {
                # Wenn die Gruppe nicht existiert, erstelle sie
                Write-Host "Gruppe '$group' existiert nicht. Erstelle sie..."
                New-ADGroup -Name $group -GroupScope Global -PassThru
            } else {
                Write-Host "Gruppe '$group' existiert bereits."
            }
        }
    }

    # Leeres Hash-Table für die Parameter des Benutzers
    $ADUserParams = @{}

    # Durchlaufe alle Eigenschaften des $user-Objekts und füge sie den Parametern hinzu
    foreach ($property in $user.PSObject.Properties) {
        if ($null -ne $property.Value -and $property.Value -ne "") {
            # Besondere Behandlung des AccountPassword
            if ($property.Name -eq "AccountPassword") {
                # Wenn das AccountPassword leer oder null ist, setze ein Standardpasswort
                if ($property.Value -eq $null -or $property.Value -eq "") {
                    $SecurePassword = ConvertTo-SecureString "Passw0rd" -AsPlainText -Force
                    $ADUserParams.Add("AccountPassword", $SecurePassword)
                } else {
                    # Konvertiere das angegebene Passwort in ein SecureString
                    $SecurePassword = ConvertTo-SecureString $property.Value -AsPlainText -Force
                    $ADUserParams.Add("AccountPassword", $SecurePassword)
                }
            }
            elseif ($property.Name -ne "GroupMember") {
                # Füge den Parameter hinzu, wenn der Wert nicht leer oder null ist
                $ADUserParams.Add($property.Name, $property.Value)
            }
        }
    }

    # Überprüfe und setze SamAccountName, wenn er leer oder nicht gesetzt ist
    if (-not $ADUserParams.ContainsKey("UserPrincipalName") -or [string]::IsNullOrEmpty($ADUserParams["UserPrincipalName"])) {
        $UserPrincipalName = ($user.GivenName + $user.Surname) -replace "\s+", ""  # Entfernt Leerzeichen, falls welche im Namen vorhanden sind
        $DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        $ADUserParams["UserPrincipalName"] = $UserPrincipalName+"@"+$DomainName 
    }

    # Überprüfe und setze SamAccountName, wenn er leer oder nicht gesetzt ist
    if (-not $ADUserParams.ContainsKey("SamAccountName") -or [string]::IsNullOrEmpty($ADUserParams["SamAccountName"])) {
        $SamAccountName = ($user.GivenName + $user.Surname) -replace "\s+", ""  # Entfernt Leerzeichen, falls welche im Namen vorhanden sind
        $DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        $ADUserParams["SamAccountName"] = $SamAccountName
    }

    # Überprüfe und setze DisplayName, wenn er leer oder nicht gesetzt ist
    if (-not $ADUserParams.ContainsKey("DisplayName") -or [string]::IsNullOrEmpty($ADUserParams["DisplayName"])) {
        $DisplayName = ($user.GivenName + " " + $user.Surname).Trim()  # Vorname Nachname mit Leerzeichen
        $ADUserParams["DisplayName"] = $DisplayName
    }

    # Überprüfe und setze 'Name', wenn er leer oder nicht gesetzt ist
    if (-not $ADUserParams.ContainsKey("Name") -or [string]::IsNullOrEmpty($ADUserParams["Name"])) {
        $Name = ($user.GivenName + $user.Surname).Trim()
        $ADUserParams["Name"] = $Name
    }

    New-ADUser @ADUserParams

    # Wenn Gruppenmitgliedschaften angegeben sind, füge den Benutzer den Gruppen hinzu
    if ($user.PSObject.Properties.Match('GroupMember')) {
        foreach ($group in $groupList) {
            # Füge den Benutzer der entsprechenden Gruppe hinzu
            Add-ADGroupMember -Identity $group -Members  $ADUserParams["SamAccountName"]
        }
    }
}
