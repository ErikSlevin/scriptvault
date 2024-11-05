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
    @("AccountPassword", "Passwort für den Account", "Beispiel: Pa$$w0rd (String)"),
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
$preselectedAttributes = @("Surname", "GivenName", "AccountPassword")
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
    $formDataEntry.Controls.Add($buttonSave)

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

# Zeige das Auswahlformular an und warte, bis es geschlossen wird
$formSelectAttributes.ShowDialog()

# Ausgabe der eingegebenen Daten nach dem Schließen des Formulars
$enteredData