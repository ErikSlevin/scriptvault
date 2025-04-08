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

# Liste von Gewürzen mit Übersetzungen in verschiedenen Sprachen
# Sprachen: Deutsch (DEU), Englisch (ENG), Französisch (FRA), Portugiesisch (POR), Spanisch (ESP), Polnisch (POL)

spices = [
    {'DEU': 'Anis', 'ENG': 'Anise', 'FRA': 'Anis', 'POR': 'Anis', 'ESP': 'Anís', 'POL': 'Anyż'},
    {'DEU': 'Bärlauch', 'ENG': 'Wild garlic', 'FRA': 'Ail des ours', 'POR': 'Alho selvagem', 'ESP': 'Ajo silvestre', 'POL': 'Czosnek niedźwiedzi'},
    {'DEU': 'Basilikum', 'ENG': 'Basil', 'FRA': 'Basilic', 'POR': 'Manjericão', 'ESP': 'Albahaca', 'POL': 'Bazylia'},
    {'DEU': 'Bohnenkraut', 'ENG': 'Savory', 'FRA': 'Sarriette', 'POR': 'Segurelha', 'ESP': 'Ajedrea', 'POL': 'Cząber'},
    {'DEU': 'Cayenne Pfeffer', 'ENG': 'Cayenne pepper', 'FRA': 'Poivre de Cayenne', 'POR': 'Pimenta caiena', 'ESP': 'Pimienta de Cayena', 'POL': 'Pieprz cayenne'},
    {'DEU': 'Chili', 'ENG': 'Chili', 'FRA': 'Piment', 'POR': 'Chili', 'ESP': 'Chile', 'POL': 'Chili'},
    {'DEU': 'Chili Fäden', 'ENG': 'Chili threads', 'FRA': 'Filaments de piment', 'POR': 'Fios de chili', 'ESP': 'Hilos de chile', 'POL': 'Nitki chili'},
    {'DEU': 'Chili ganz', 'ENG': 'Whole chili', 'FRA': 'Piment entier', 'POR': 'Chili inteiro', 'ESP': 'Chile entero', 'POL': 'Chili w całości'},
    {'DEU': 'Chili gemahlen', 'ENG': 'Ground chili', 'FRA': 'Piment moulu', 'POR': 'Chili moído', 'ESP': 'Chile molido', 'POL': 'Chili mielone'},
    {'DEU': 'Curry', 'ENG': 'Curry', 'FRA': 'Curry', 'POR': 'Curry', 'ESP': 'Curry', 'POL': 'Curry'},
    {'DEU': 'Curry mild', 'ENG': 'Mild curry', 'FRA': 'Curry doux', 'POR': 'Curry suave', 'ESP': 'Curry suave', 'POL': 'Curry łagodne'},
    {'DEU': 'Curry scharf', 'ENG': 'Spicy curry', 'FRA': 'Curry épicé', 'POR': 'Curry picante', 'ESP': 'Curry picante', 'POL': 'Curry ostre'},
    {'DEU': 'Dill', 'ENG': 'Dill', 'FRA': 'Aneth', 'POR': 'Endro', 'ESP': 'Eneldo', 'POL': 'Koper'},
    {'DEU': 'Estragon', 'ENG': 'Tarragon', 'FRA': 'Estragon', 'POR': 'Estragão', 'ESP': 'Estragón', 'POL': 'Estragon'},
    {'DEU': 'Fenchel', 'ENG': 'Fennel', 'FRA': 'Fenouil', 'POR': 'Funcho', 'ESP': 'Hinojo', 'POL': 'Koper włoski'},
    {'DEU': 'Garam Masala', 'ENG': 'Garam Masala', 'FRA': 'Garam Masala', 'POR': 'Garam Masala', 'ESP': 'Garam Masala', 'POL': 'Garam masala'},
    {'DEU': 'Gyros', 'ENG': 'Gyros spice mix', 'FRA': 'Épices pour gyros', 'POR': 'Tempero para gyros', 'ESP': 'Especia para gyros', 'POL': 'Przyprawa do gyrosa'},
    {'DEU': 'Harissa', 'ENG': 'Harissa', 'FRA': 'Harissa', 'POR': 'Harissa', 'ESP': 'Harissa', 'POL': 'Harissa'},
    {'DEU': 'Ingwer', 'ENG': 'Ginger', 'FRA': 'Gingembre', 'POR': 'Gengibre', 'ESP': 'Jengibre', 'POL': 'Imbir'},
    {'DEU': 'Kardamon', 'ENG': 'Cardamom', 'FRA': 'Cardamome', 'POR': 'Cardamomo', 'ESP': 'Cardamomo', 'POL': 'Kardamon'},
    {'DEU': 'Knoblauch', 'ENG': 'Garlic', 'FRA': 'Ail', 'POR': 'Alho', 'ESP': 'Ajo', 'POL': 'Czosnek'},
    {'DEU': 'Koriander', 'ENG': 'Coriander', 'FRA': 'Coriandre', 'POR': 'Coentro', 'ESP': 'Cilantro', 'POL': 'Kolendra'},
    {'DEU': 'Kräuter der Provence', 'ENG': 'Herbs of Provence', 'FRA': 'Herbes de Provence', 'POR': 'Ervas de Provence', 'ESP': 'Hierbas de Provenza', 'POL': 'Zioła prowansalskie'},
    {'DEU': 'Kreuzkümmel', 'ENG': 'Cumin', 'FRA': 'Cumin', 'POR': 'Cominho', 'ESP': 'Comino', 'POL': 'Kmin rzymski'},
    {'DEU': 'Kümmel', 'ENG': 'Caraway', 'FRA': 'Carvi', 'POR': 'Alcaravia', 'ESP': 'Alcaravea', 'POL': 'Kminek'},
    {'DEU': 'Kurkuma', 'ENG': 'Turmeric', 'FRA': 'Curcuma', 'POR': 'Açafrão da Terra', 'ESP': 'Cúrcuma', 'POL': 'Kurkuma'},
    {'DEU': 'Lorbeer Blätter', 'ENG': 'Bay leaves', 'FRA': 'Feuilles de laurier', 'POR': 'Folhas de louro', 'ESP': 'Hojas de laurel', 'POL': 'Liście laurowe'},
    {'DEU': 'Majoran', 'ENG': 'Marjoram', 'FRA': 'Marjolaine', 'POR': 'Manjerona', 'ESP': 'Mejorana', 'POL': 'Majeranek'},
    {'DEU': 'Meersalz', 'ENG': 'Sea salt', 'FRA': 'Sel marin', 'POR': 'Sal marinho', 'ESP': 'Sal marina', 'POL': 'Sól morska'},
    {'DEU': 'Mehl', 'ENG': 'Flour', 'FRA': 'Farine', 'POR': 'Farinha', 'ESP': 'Harina', 'POL': 'Mąka'},
    {'DEU': 'Minze', 'ENG': 'Mint', 'FRA': 'Menthe', 'POR': 'Hortelã', 'ESP': 'Menta', 'POL': 'Mięta'},
    {'DEU': 'Muskat', 'ENG': 'Nutmeg', 'FRA': 'Noix de muscade', 'POR': 'Noz-moscada', 'ESP': 'Nuez moscada', 'POL': 'Gałka muszkatołowa'},
    {'DEU': 'Nelken', 'ENG': 'Cloves', 'FRA': 'Clous de girofle', 'POR': 'Cravo-da-índia', 'ESP': 'Clavos de olor', 'POL': 'Goździki'},
    {'DEU': 'Oregano', 'ENG': 'Oregano', 'FRA': 'Origan', 'POR': 'Orégano', 'ESP': 'Orégano', 'POL': 'Oregano'},
    {'DEU': 'Paprika', 'ENG': 'Paprika', 'FRA': 'Paprika', 'POR': 'Páprica', 'ESP': 'Pimentón', 'POL': 'Papryka'},
    {'DEU': 'Paprika edelsüß', 'ENG': 'Sweet paprika', 'FRA': 'Paprika doux', 'POR': 'Páprica doce', 'ESP': 'Pimentón dulce', 'POL': 'Papryka słodka'},
    {'DEU': 'Paprika geräuchert', 'ENG': 'Smoked paprika', 'FRA': 'Paprika fumé', 'POR': 'Páprica defumada', 'ESP': 'Pimentón ahumado', 'POL': 'Papryka wędzona'},
    {'DEU': 'Paprika rosenscharf', 'ENG': 'Hot paprika', 'FRA': 'Paprika fort', 'POR': 'Páprica picante', 'ESP': 'Pimentón picante', 'POL': 'Papryka ostra'},
    {'DEU': 'Petersilie', 'ENG': 'Parsley', 'FRA': 'Persil', 'POR': 'Salsa', 'ESP': 'Perejil', 'POL': 'Pietruszka'},
    {'DEU': 'Pfeffer', 'ENG': 'Pepper', 'FRA': 'Poivre', 'POR': 'Pimenta', 'ESP': 'Pimienta', 'POL': 'Pieprz'},
    {'DEU': 'Pfeffer bunt', 'ENG': 'Mixed peppercorns', 'FRA': 'Mélange de poivres', 'POR': 'Pimenta variada', 'ESP': 'Pimienta variada', 'POL': 'Pieprz kolorowy'},
    {'DEU': 'Pfeffer ganz', 'ENG': 'Whole pepper', 'FRA': 'Poivre en grains', 'POR': 'Pimenta em grãos', 'ESP': 'Pimienta en grano', 'POL': 'Pieprz w ziarnach'},
    {'DEU': 'Pfeffer gemahlen', 'ENG': 'Ground pepper', 'FRA': 'Poivre moulu', 'POR': 'Pimenta moída', 'ESP': 'Pimienta molida', 'POL': 'Pieprz mielony'},
    {'DEU': 'Pfeffer grün', 'ENG': 'Green pepper', 'FRA': 'Poivre vert', 'POR': 'Pimenta verde', 'ESP': 'Pimienta verde', 'POL': 'Pieprz zielony'},
    {'DEU': 'Pfeffer schwarz', 'ENG': 'Black pepper', 'FRA': 'Poivre noir', 'POR': 'Pimenta preta', 'ESP': 'Pimienta negra', 'POL': 'Pieprz czarny'},
    {'DEU': 'Pfeffer weiß', 'ENG': 'White pepper', 'FRA': 'Poivre blanc', 'POR': 'Pimenta branca', 'ESP': 'Pimienta blanca', 'POL': 'Pieprz biały'},
    {'DEU': 'Piment', 'ENG': 'Allspice', 'FRA': 'Piment de la Jamaïque', 'POR': 'Pimenta da Jamaica', 'ESP': 'Pimienta de Jamaica', 'POL': 'Ziele angielskie'},
    {'DEU': 'Pommes Frites', 'ENG': 'French fries', 'FRA': 'Frites', 'POR': 'Batatas fritas', 'ESP': 'Papas fritas', 'POL': 'Przyprawa do frytek'},
    {'DEU': 'Rosmarin', 'ENG': 'Rosemary', 'FRA': 'Romarin', 'POR': 'Alecrim', 'ESP': 'Romero', 'POL': 'Rozmaryn'},
    {'DEU': 'Safran', 'ENG': 'Saffron', 'FRA': 'Safran', 'POR': 'Açafrão', 'ESP': 'Azafrán', 'POL': 'Szafran'},
    {'DEU': 'Salbei', 'ENG': 'Sage', 'FRA': 'Sauge', 'POR': 'Sálvia', 'ESP': 'Salvia', 'POL': 'Szałwia'},
    {'DEU': 'Salz', 'ENG': 'Salt', 'FRA': 'Sel', 'POR': 'Sal', 'ESP': 'Sal', 'POL': 'Sól'},
    {'DEU': 'Schnittlauch', 'ENG': 'Chives', 'FRA': 'Ciboulette', 'POR': 'Cebolinha', 'ESP': 'Cebollino', 'POL': 'Szczypiorek'},
    {'DEU': 'Sellerie', 'ENG': 'Celery', 'FRA': 'Céleri', 'POR': 'Aipo', 'ESP': 'Apio', 'POL': 'Seler'},
    {'DEU': 'Sesam', 'ENG': 'Sesame', 'FRA': 'Sésame', 'POR': 'Gergelim', 'ESP': 'Sésamo', 'POL': 'Sezam'},
    {'DEU': 'Thymian', 'ENG': 'Thyme', 'FRA': 'Thym', 'POR': 'Tomilho', 'ESP': 'Tomillo', 'POL': 'Tymianek'},
    {'DEU': 'Vanille', 'ENG': 'Vanilla', 'FRA': 'Vanille', 'POR': 'Baunilha', 'ESP': 'Vainilla', 'POL': 'Wanilia'},
    {'DEU': 'Zimt', 'ENG': 'Cinnamon', 'FRA': 'Cannelle', 'POR': 'Canela', 'ESP': 'Canela', 'POL': 'Cynamon'},
    {'DEU': 'Zucker', 'ENG': 'Sugar', 'FRA': 'Sucre', 'POR': 'Açúcar', 'ESP': 'Azúcar', 'POL': 'Cukier'},
    {'DEU': 'Zwiebel', 'ENG': 'Onion', 'FRA': 'Oignon', 'POR': 'Cebola', 'ESP': 'Cebolla', 'POL': 'Cebula'},
]

# Funktion, um Zeichen entsprechend der Mapping-Tabelle zu ersetzen
def replace_special_chars(text):
    return ''.join(char_mapping.get(c, c) for c in text)

def get_active_app():
    """ Gibt die aktive Application-Instanz zurück. """
    return adsk.core.Application.get()

def get_active_design():
    """ Gibt das aktive Fusion-Design zurück. """
    app = get_active_app()
    return adsk.fusion.Design.cast(app.activeProduct)

def get_gewuerze_folder():
    """
    Gibt den Pfad zum Desktop-Ordner 'Gewuerze' des aktuellen Benutzers zurück.
    Erstellt den Ordner, falls er nicht existiert.
    """
    # Pfad zum Desktop ermitteln
    desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")

    # Zielordner: 'Gewuerze'
    gewuerze_path = os.path.join(desktop_path, "Gewuerze")

    # Ordner bei Bedarf erstellen
    os.makedirs(gewuerze_path, exist_ok=True)

    return gewuerze_path

def create_folder_structure(desktop_path):
    """
    Erstellt die Ordnerstruktur unterhalb von:
    <Desktop>\Gewuerze\...

    Gibt den Pfad zum Fusion-Dateienordner sowie das Dictionary mit den Länderordnern zurück.
    """

    # Gewuerze-Root unterhalb des Desktop-Pfads
    root_path = os.path.join(desktop_path, "Gewuerze")
    os.makedirs(root_path, exist_ok=True)

    # Ordner für Fusion-Dateien
    fusion_folder = os.path.join(root_path, "00_Fusion_Files")
    os.makedirs(fusion_folder, exist_ok=True)

    # Mapping der Länderordner
    country_folders = {
        "DEU": "01_DEU",
        "ENG": "02_ENG",
        "FRA": "03_FRA",
        "POR": "04_POR",
        "ESP": "05_ESP",
        "POL": "06_POL"
    }

    # Typ-Ordner (A bis E)
    type_folders = ["TYPE A", "TYPE B", "TYPE C", "TYPE D", "TYPE E"]

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

    # Stelle sicher, dass der Exportordner existiert
    os.makedirs(export_path, exist_ok=True)

    # Suche den Körper anhand seines Namens
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

    design = get_active_design()
    export_mgr = design.exportManager
    
    fusion_file_name = f"{comment}-multi.f3d"
    fusion_file_path = os.path.join(fusion_folder, fusion_file_name)
    
    # Erstelle Exportoptionen für das Fusion Archive
    fusion_archive_options = export_mgr.createFusionArchiveExportOptions(fusion_file_path)
    export_mgr.execute(fusion_archive_options)
    
    return fusion_file_name

def request_user_inputs():
    """
    Fordert den Benutzer zur Eingabe eines deutschen Begriffs auf.
    Sucht dann die zugehörigen Übersetzungen im spices-Array und gibt diese zurück.
    """
    ui = get_active_app().userInterface

    # Eingabefeld für den deutschen Begriff
    prompt = "Bitte gib den deutschen Gewürzbegriff ein:"
    title = "Gewürzeingabe (DEU)"
    (user_input, cancelled) = ui.inputBox(prompt, title, "")
    if cancelled:
        return None
    
    # Suchen des Begriffs im Array
    matching_entry = next((item for item in spices if item["DEU"].lower() == user_input.strip().lower()), None)

    if not matching_entry:
        ui.messageBox(f"Der Begriff '{user_input}' wurde nicht im Gewürz-Array gefunden.")
        return None

    # Extrahiere die Übersetzungen in der gewünschten Reihenfolge
    countries = ["DEU", "ENG", "FRA", "POR", "ESP", "POL"]
    user_inputs = [matching_entry[country] for country in countries]

    return user_inputs

def update_user_comments(user_inputs):
    """
    Aktualisiert die Kommentare der User-Parameter für die Länder
    DEU, ENG, FRA, POL und ESP, indem die comment-Eigenschaft
    der entsprechenden Parameter auf die Werte aus den Eingabefeldern gesetzt wird.
    Vor dem Setzen wird jeder '\' in einen Zeilenumbruch umgewandelt.
    
    :param user_inputs: Liste von Strings mit den Kommentarwerten in Länderreihenfolge
    """
    # Hole das aktive Design und die zugehörigen User-Parameter
    design = get_active_design()
    user_params = design.userParameters

    # Liste der Länderkürzel in definierter Reihenfolge
    countries = ["DEU", "ENG", "FRA", "POR", "ESP", "POL"]

    # Iteriere über jedes Land und setze den Kommentar des entsprechenden Parameters
    for i, country in enumerate(countries):
        param = user_params.itemByName(country)  # Hole den Parameter für das Land

        if param:
            # Ersetze '\' durch Zeilenumbruch und setze den Kommentar
            cleaned_comment = user_inputs[i].replace("\\", "\n")
            param.comment = cleaned_comment

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
        desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")

        # Erstelle Ordnerstruktur und hole Mapping der Länderordner
        fusion_folder, country_folders = create_folder_structure(desktop_path)
        
        # Definiere die Länder und Typen
        countries = ["DEU", "ENG", "FRA", "POR", "ESP", "POL"]
        types = ["A", "B", "C", "D", "E", "F", "G", "H"]

        # Iteriere über die Länder
        for country in countries:
            comment = get_comment(country)

            # Iteriere über die Typen und exportiere die Körper
            for t in types:
                body_name = f"{country}-{t}"
                type_folder = f"TYPE {t}"

                # Erstelle den vollständigen Pfad für die jeweiligen Formate
                stl_path = os.path.join(desktop_path, "Gewuerze", country_folders[country], type_folder, "stl")
                mf3_path = os.path.join(desktop_path, "Gewuerze", country_folders[country], type_folder, "3mf")
                
                stl_file = export_body(body_name, stl_path, "stl", comment)
                three_mf_file = export_body(body_name, mf3_path, "3mf", comment)

        # Exportiere die Fusion-Datei mit dem Kommentar des Landes DEU
        comment = get_comment("DEU")
        fusion_file_name = export_f3d(fusion_folder, comment)

        # Nach Abschluss: Bewege die Timeline 5 Schritte zurück
        design = get_active_design()
        timeline_var = design.timeline
        for i in range(6):
            # Bewege einen Schritt zurück in der Timeline
            returnValue = timeline_var.moveToPreviousStep()

         # Fordere den Benutzer zur Eingabe von Kommentaren auf
        user_inputs = request_user_inputs()
        if not user_inputs:
            return
        update_user_comments(user_inputs)

        get_active_app().userInterface.messageBox(f"Parameter aktualisieren!\n\nVolumenkörper >> ändern >> Parameter ändern öffnen und danach schließen und Schrittweise die timeline aktualisieren")


    except Exception as e:
        # Bei Fehlern wird eine Fehlermeldung angezeigt
        get_active_app().userInterface.messageBox(f"Fehler: {str(e)}")