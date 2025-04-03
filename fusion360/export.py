# Importiere benötigte Module: adsk-Module für Fusion 360, sowie os und re für Dateisystem und Regex-Operationen
import adsk.core, adsk.fusion, adsk.cam, os, re

# Mapping von Umlauten und Sonderzeichen zu ihren Entsprechungen
char_mapping = {
    'Ä': 'Ae', 'ä': 'ae', 'Ö': 'Oe', 'ö': 'oe', 'Ü': 'Ue', 'ü': 'ue', 'ß': 'ss',
    'À': 'A', 'à': 'a', 'È': 'E', 'é': 'e', 'Ê': 'E', 'è': 'e', 'Ç': 'C', 'ç': 'c', 
    'Ñ': 'N', 'ñ': 'n', 'Ô': 'O', 'ô': 'o', 'Î': 'I', 'î': 'i', 'Ï': 'I', 'ï': 'i',
    'Æ': 'Ae', 'æ': 'ae', 'Œ': 'Oe', 'œ': 'oe',
    'Á': 'A', 'á': 'a', 'Í': 'I', 'í': 'i', 'Ó': 'O', 'ó': 'o', 'Ú': 'U', 'ú': 'u',
    'Ł': 'L', 'ł': 'l', 'Ś': 'S', 'ś': 's', 'Ź': 'Z', 'ź': 'z', 'Ż': 'Z', 'ż': 'z',
    'Ć': 'C', 'ć': 'c', 'Ń': 'N', 'ń': 'n'
}

# Funktion, um Zeichen entsprechend der Mapping-Tabelle zu ersetzen
def replace_special_chars(text):
    return ''.join(char_mapping.get(c, c) for c in text)

def log_status(message):
    """ Gibt eine Statusmeldung in der Konsole aus. """
    print(f"[INFO] {message}")

def get_active_app():
    """ Gibt die aktive Application-Instanz zurück. """
    return adsk.core.Application.get()

def get_active_design():
    """ Gibt das aktive Fusion-Design zurück. """
    app = get_active_app()
    return adsk.fusion.Design.cast(app.activeProduct)

def select_folder():
    """
    Öffnet einen Dialog zur Ordnerauswahl und setzt den Desktop als Standardverzeichnis.
    Wenn der Ordner 'Gewuerze' bereits existiert, wird dieser direkt zurückgegeben.
    Gibt den ausgewählten Ordnerpfad zurück oder None, wenn kein Ordner ausgewählt wurde.
    """
    ui = get_active_app().userInterface
    desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")
    gewuerze_folder_path = os.path.join(desktop_path, "Gewuerze")
    
    # Überprüfen, ob der Ordner "Gewuerze" bereits existiert
    if os.path.isdir(gewuerze_folder_path):
        return gewuerze_folder_path
    
    # Wenn der Ordner nicht existiert, Dialog öffnen
    dlg = ui.createFolderDialog()
    dlg.title = "Wähle das Zielverzeichnis"
    dlg.initialDirectory = desktop_path
    
    if dlg.showDialog() == adsk.core.DialogResults.DialogOK:
        return dlg.folder
    return None

def create_folder_structure(base_path):
    """
    Erstellt die Ordnerstruktur für den Export:
      - Root-Ordner "Gewuerze" mit Unterordnern für Fusion-Dateien und Länderkategorien.
      - Innerhalb der Länderordner werden Unterordner für die einzelnen Typen (TYPE A bis TYPE E) mit den Exportformaten "stl" und "3mf" angelegt.
    Gibt den Pfad zum Fusion-Dateienordner sowie das Dictionary mit den Länderordnern zurück.
    """
    log_status("Erstelle Ordnerstruktur...")
    
    # Erstelle den Root-Ordner "Gewuerze"
    root_path = os.path.join(base_path, "Gewuerze")
    os.makedirs(root_path, exist_ok=True)
    
    # Ordner für Fusion-Dateien
    fusion_folder = os.path.join(root_path, "00_Fusion_Files")
    os.makedirs(fusion_folder, exist_ok=True)

    # Mapping der Länder zu ihren entsprechenden Ordnernamen
    country_folders = {
        "DEU": "01_DEU",
        "ENG": "02_ENG",
        "FRA": "03_FRA",
        "POL": "04_POL",
        "ESP": "05_ESP"
    }

    # Liste der Typ-Ordner
    type_folders = ["TYPE A", "TYPE B", "TYPE C", "TYPE D", "TYPE E"]

    # Erstelle für jedes Land und jeden Typ die Unterordner "stl" und "3mf"
    for country, folder_name in country_folders.items():
        country_path = os.path.join(root_path, folder_name)
        os.makedirs(country_path, exist_ok=True)
        for folder in type_folders:
            os.makedirs(os.path.join(country_path, folder, "stl"), exist_ok=True)
            os.makedirs(os.path.join(country_path, folder, "3mf"), exist_ok=True)

    return fusion_folder, country_folders

def get_comment(country):
    """
    Ruft den Kommentar (aus den User-Parametern des Designs) für das angegebene Land ab.
    Nicht erlaubte Zeichen werden durch Unterstriche ersetzt.
    Falls kein Kommentar vorhanden ist, wird "NO_COMMENT" zurückgegeben.
    """
    design = get_active_design()
    user_params = design.userParameters

    # Parametername entspricht dem Ländercode (z.B. "DEU")
    country_param = user_params.itemByName(country)

    if country_param and country_param.comment:
        # Ersetze Sonderzeichen und Umlaute mit den entsprechenden ASCII-Werten
        sanitized_comment = replace_special_chars(country_param.comment)
        # Ersetze unerwünschte Zeichen (die keine Buchstaben, Zahlen, Bindestriche oder Unterstriche sind) durch Unterstriche
        sanitized_comment = re.sub(r'[^a-zA-Z0-9_-]', '_', sanitized_comment)
        return sanitized_comment
    return "NO_COMMENT"

def export_body(body_name, export_path, file_format, comment):
    """
    Exportiert einen Körper (body) aus dem aktiven Design in das gewünschte Dateiformat (stl oder 3mf).
    Der Dateiname wird aus dem Körpernamen und dem Kommentar generiert.
    Gibt den Dateinamen zurück oder None, wenn der Körper nicht gefunden wurde.
    """
    design = get_active_design()
    export_mgr = design.exportManager
    root_comp = design.rootComponent

    # Suche den Körper anhand seines Namens mithilfe von next() für mehr Übersichtlichkeit
    body = next((b for b in root_comp.bRepBodies if b.name == body_name), None)

    if not body:
        return None

    # Erstelle Dateiname und vollständigen Pfad
    file_name = f"{body_name}_{comment}.{file_format}"
    file_path = os.path.join(export_path, file_name)

    # Erstelle die entsprechenden Exportoptionen
    if file_format == "stl":
        export_options = export_mgr.createSTLExportOptions(body, file_path)
        export_options.meshRefinement = adsk.fusion.MeshRefinementSettings.MeshRefinementMedium
    elif file_format == "3mf":
        export_options = export_mgr.createC3MFExportOptions(body, file_path)
    else:
        return None

    # Führe den Export aus
    export_mgr.execute(export_options)
    return file_name

def export_f3d(fusion_folder, comment):
    """
    Exportiert das gesamte Design als Fusion Archive (f3d-Datei) in den angegebenen Ordner.
    Der Dateiname wird aus "DEU", dem Kommentar und dem Suffix "-multi" generiert.
    Gibt den Dateinamen der Fusion-Datei zurück.
    """
    log_status("Speichere Fusion-Datei...")
    design = get_active_design()
    export_mgr = design.exportManager
    
    fusion_file_name = f"DEU.{comment}-multi.f3d"
    fusion_file_path = os.path.join(fusion_folder, fusion_file_name)
    
    # Erstelle Exportoptionen für das Fusion Archive
    fusion_archive_options = export_mgr.createFusionArchiveExportOptions(fusion_file_path)
    export_mgr.execute(fusion_archive_options)
    
    return fusion_file_name

def request_user_inputs():
    """
    Fordert den Benutzer nacheinander zur Eingabe von Kommentaren für die Länder
    DEU, ENG, FRA, POL und ESP auf. Jedes Eingabefeld erscheint in einem eigenen Fenster.
    """
    ui = get_active_app().userInterface
    countries = ["DEU", "ENG", "FRA", "POL", "ESP"]
    user_inputs = []

    for country in countries:
        prompt = f"Bitte gib den Kommentar für {country} ein:"   # Eingabeaufforderung
        title = f"Kommentar für {country} eingeben"               # Fenstertitel
        (user_input, cancelled) = ui.inputBox(prompt, title, "")
        if cancelled:
            return None
        user_inputs.append(user_input)
    
    return user_inputs

def update_user_comments(user_inputs):
    """
    Aktualisiert die Kommentare der User-Parameter für die Länder
    DEU, ENG, FRA, POL und ESP, indem die comment-Eigenschaft
    der entsprechenden Parameter auf die Werte aus den Eingabefeldern gesetzt wird.
    """
    # Hole das aktive Design und die zugehörigen User-Parameter
    design = get_active_design()
    user_params = design.userParameters
    
    countries = ["DEU", "ENG", "FRA", "POL", "ESP"]
    
    # Iteriere über jedes Land und setze den Kommentar des entsprechenden Parameters
    for i, country in enumerate(countries):
        param = user_params.itemByName(country)  # Hole den Parameter für das Land
        
        if param:
            # Setze den Kommentar des Parameters auf den Wert aus dem Inputfeld
            param.comment = user_inputs[i]

def run(context):
    """
    Hauptfunktion, die den gesamten Exportprozess steuert:
      - Ordnerauswahl und Erstellung der Ordnerstruktur
      - Export der einzelnen Körper in den Formaten STL und 3MF
      - Export der gesamten Fusion-Datei
      - Anzeige einer Zusammenfassung des Exportprozesses
      - Verschiebt die Timeline 5 Schritte zurück
    """
    try:
        # Ordner auswählen
        base_path = select_folder()
        if not base_path:
            return

        # Erstelle Ordnerstruktur und hole Mapping der Länderordner
        fusion_folder, country_folders = create_folder_structure(base_path)
        
        # Definiere die Länder und Typen
        countries = ["DEU", "ENG", "FRA", "POL", "ESP"]
        types = ["A", "B", "C", "D", "E"]

        export_summary = ["Gewuerze"]  # Start der Baumstruktur
        log_status("Starte Exportprozess...")

        # Iteriere über die Länder
        for country in countries:
            comment = get_comment(country)
            log_status(f"Starte Export für {country}...")

            # Landesspezifische Zusammenfassung
            country_summary = f"├── {country} ({comment})"

            # Iteriere über die Typen und exportiere die Körper
            for t in types:
                body_name = f"{country}-{t}"
                type_folder = f"TYPE {t}"

                log_status(f"-> Exportiere {body_name} (STL & 3MF)...")

                # Erstelle den vollständigen Pfad für die jeweiligen Formate
                stl_path = os.path.join(base_path, "Gewuerze", country_folders[country], type_folder, "stl")
                mf3_path = os.path.join(base_path, "Gewuerze", country_folders[country], type_folder, "3mf")
                
                stl_file = export_body(body_name, stl_path, "stl", comment)
                three_mf_file = export_body(body_name, mf3_path, "3mf", comment)

                # Füge die exportierten Dateien zur Zusammenfassung hinzu
                if t == 'E':
                    country_summary += f"\n│   └── Type {t}: {comment} (.stl & .3mf)"
                else:
                    country_summary += f"\n│   ├── Type {t}: {comment} (.stl & .3mf)"

            # Füge die Zusammenfassung für das aktuelle Land zur Gesamtstruktur hinzu
            export_summary.append(country_summary)

        # Exportiere die Fusion-Datei mit dem Kommentar des Landes DEU
        comment = get_comment("DEU")
        fusion_file_name = export_f3d(fusion_folder, comment)

        export_summary.append(f"└── Fusion File: {fusion_file_name}")

        # Zeige eine strukturierte Zusammenfassung des gesamten Exportprozesses an
        export_message = "\n".join(export_summary)
        get_active_app().userInterface.messageBox(f"Export abgeschlossen!\n\n{export_message}")

        # Nach Abschluss: Bewege die Timeline 5 Schritte zurück
        design = get_active_design()
        timeline_var = design.timeline
        for i in range(5):
            # Bewege einen Schritt zurück in der Timeline
            returnValue = timeline_var.moveToPreviousStep()
            log_status(f"Timeline Schritt {i+1} zurückgesetzt, Rückgabewert: {returnValue}")


         # Fordere den Benutzer zur Eingabe von Kommentaren auf
        user_inputs = request_user_inputs()
        if not user_inputs:
            return
        update_user_comments(user_inputs)

        get_active_app().userInterface.messageBox(f"Parameter aktualisieren!\n\nVolumenkörper >> ändern >> Parameter ändern öffnen und danach schließen und Schrittweise die timeline aktualisieren")


    except Exception as e:
        # Bei Fehlern wird eine Fehlermeldung angezeigt
        get_active_app().userInterface.messageBox(f"Fehler: {str(e)}")