"""
INSTALLATION DER ABHÄNGIGKEITEN:
pip install Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont

def add_copyright(input_folder, output_folder, text):
    # Prüfen, ob der Zielordner existiert, ansonsten erstellen
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Versuchen, die Schriftart Arial zu laden
    try:
        # 36 ist die Schriftgröße – bei 4K Bildern ggf. auf 80+ erhöhen
        font = ImageFont.truetype("arial.ttf", 36) 
    except:
        # Falls Arial nicht gefunden wird (z.B. Linux), Fallback auf Standardschrift
        font = ImageFont.load_default()

    # Alle Dateien im Quellordner durchgehen
    for filename in os.listdir(input_folder):
        # Nur Bilder mit diesen Endungen bearbeiten
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            # Bild öffnen
            img = Image.open(os.path.join(input_folder, filename))
            draw = ImageDraw.Draw(img)
            
            # Textgröße (Bounding Box) berechnen, um die Position zu bestimmen
            bbox = draw.textbbox((0, 0), text, font=font)
            textwidth = bbox[2] - bbox[0]
            textheight = bbox[3] - bbox[1]
            
            # Position berechnen: Bildbreite minus Textbreite minus 20px Rand
            width, height = img.size
            x = width - textwidth - 20
            y = height - textheight - 20
            
            # 1. Schatten zeichnen (schwarzer Text, leicht versetzt um 1px)
            # Das sorgt dafür, dass man den Text auf jedem Untergrund lesen kann
            draw.text((x + 1, y + 1), text, font=font, fill="black")
            
            # 2. Eigentlichen Text zeichnen (weiß)
            draw.text((x, y), text, font=font, fill="white")
            
            # Das bearbeitete Bild im Zielordner speichern
            img.save(os.path.join(output_folder, filename))
            print(f"Erfolgreich gespeichert: {filename}")

# --- EINSTELLUNGEN ---
# Das 'r' vor den Pfaden verhindert "UnicodeEscape"-Fehler unter Windows
add_copyright(
    input_folder=r"C:\Users\erikw\Desktop\DSE-Workfolder", 
    output_folder=r"C:\Users\erikw\Desktop\DSE-Workfolder-Copyright", 
    text="©2026 cults3d.com/@erikslevin"
)
