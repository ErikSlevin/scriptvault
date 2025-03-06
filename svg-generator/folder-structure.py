import os

# Das Array mit den Übersetzungen für jedes Gewürz
gewuerze = {
    "Garlic": {
        "DEU": "Knoblauch",
        "ENG": "Garlic",
        "POL": "Czosnek",
        "ESP": "Ajo",
        "FRA": "Ail"
    },
    "Chili": {
        "DEU": "Chili",
        "ENG": "Chili",
        "POL": "Chili",
        "ESP": "Chile",
        "FRA": "Chili"
    },
    "Pepper": {
        "DEU": "Pfeffer",
        "ENG": "Pepper",
        "POL": "Pieprz",
        "ESP": "Pimienta",
        "FRA": "Poivre"
    },
    "Salt": {
        "DEU": "Salz",
        "ENG": "Salt",
        "POL": "Sól",
        "ESP": "Sal",
        "FRA": "Sel"
    },
    "Paprika": {
        "DEU": "Paprika",
        "ENG": "Paprika",
        "POL": "Papryka",
        "ESP": "Pimentón",
        "FRA": "Paprika"
    },
    "Turmeric": {
        "DEU": "Kurkuma",
        "ENG": "Turmeric",
        "POL": "Kurkum",
        "ESP": "Cúrcuma",
        "FRA": "Curcuma"
    },
    "Cumin": {
        "DEU": "Kreuzkümmel",
        "ENG": "Cumin",
        "POL": "Kumin",
        "ESP": "Comino",
        "FRA": "Cumin"
    },
    "Oregano": {
        "DEU": "Oregano",
        "ENG": "Oregano",
        "POL": "Oregano",
        "ESP": "Orégano",
        "FRA": "Origan"
    },
    "Basil": {
        "DEU": "Basilikum",
        "ENG": "Basil",
        "POL": "Bazylia",
        "ESP": "Albahaca",
        "FRA": "Basilic"
    },
    "Rosemary": {
        "DEU": "Rosmarin",
        "ENG": "Rosemary",
        "POL": "Rozmaryn",
        "ESP": "Romero",
        "FRA": "Romarin"
    },
    "Thyme": {
        "DEU": "Thymian",
        "ENG": "Thyme",
        "POL": "Tymianek",
        "ESP": "Tomillo",
        "FRA": "Thym"
    },
    "Cinnamon": {
        "DEU": "Zimt",
        "ENG": "Cinnamon",
        "POL": "Cynamon",
        "ESP": "Canela",
        "FRA": "Cannelle"
    },
    "Ginger": {
        "DEU": "Ingwer",
        "ENG": "Ginger",
        "POL": "Imbir",
        "ESP": "Jengibre",
        "FRA": "Gingembre"
    },
    "Nutmeg": {
        "DEU": "Muskatnuss",
        "ENG": "Nutmeg",
        "POL": "Gałka muszkatołowa",
        "ESP": "Nuez moscada",
        "FRA": "Muscade"
    },
    "Bay leaf": {
        "DEU": "Lorbeerblatt",
        "ENG": "Bay leaf",
        "POL": "Liść laurowy",
        "ESP": "Hoja de laurel",
        "FRA": "Feuille de laurier"
    },
    "Coriander": {
        "DEU": "Koriander",
        "ENG": "Coriander",
        "POL": "Koriander",
        "ESP": "Cilantro",
        "FRA": "Coriandre"
    },
    "Mustard": {
        "DEU": "Senf",
        "ENG": "Mustard",
        "POL": "Musztarda",
        "ESP": "Mostaza",
        "FRA": "Moutarde"
    },
    "Saffron": {
        "DEU": "Safran",
        "ENG": "Saffron",
        "POL": "Szafran",
        "ESP": "Azafrán",
        "FRA": "Safran"
    },
    "Cloves": {
        "DEU": "Nelken",
        "ENG": "Cloves",
        "POL": "Goździki",
        "ESP": "Clavos de olor",
        "FRA": "Clous de girofle"
    },
    "Cardamom": {
        "DEU": "Kardamom",
        "ENG": "Cardamom",
        "POL": "Kardamon",
        "ESP": "Cardamomo",
        "FRA": "Cardamome"
    },
    "Fennel": {
        "DEU": "Fenchel",
        "ENG": "Fennel",
        "POL": "Fenkuł",
        "ESP": "Hinojo",
        "FRA": "Fenouil"
    },
    "Parsley": {
        "DEU": "Petersilie",
        "ENG": "Parsley",
        "POL": "Pietruszka",
        "ESP": "Perejil",
        "FRA": "Persil"
    }
}

# Erstellen des Hauptordners
root_dir = "Gewuerze"  # Der Hauptordner

# Sicherstellen, dass der Hauptordner existiert
if not os.path.exists(root_dir):
    os.makedirs(root_dir)

# Durch das Gewürz-Array gehen und die Ordnerstruktur erstellen
for gewuerz, uebersetzungen in gewuerze.items():
    # Für jede Sprache einen Ordner mit der richtigen Namenskonvention erstellen
    for sprache, uebersetzung in uebersetzungen.items():
        sprache_dir = os.path.join(root_dir, sprache)
        
        # Sicherstellen, dass der Ordner der Sprache existiert
        if not os.path.exists(sprache_dir):
            os.makedirs(sprache_dir)
        
        # Ordner für das Gewürz in der richtigen Sprache erstellen
        if sprache == "ENG":
            gewuerz_dir = os.path.join(sprache_dir, uebersetzung)  # Nur der englische Begriff
        else:
            gewuerz_dir = os.path.join(sprache_dir, f"{uebersetzung} ({gewuerz})")  # Anderes Format für andere Sprachen
        
        # Sicherstellen, dass der Ordner existiert
        if not os.path.exists(gewuerz_dir):
            os.makedirs(gewuerz_dir)

print("Ordnerstruktur wurde erfolgreich erstellt!")
