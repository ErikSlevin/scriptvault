#!/usr/bin/env python3
# -*- coding: utf-8 -*- 

"""
Dieses Script konvertiert einen fest definierten Text in SVG-Pfade basierend auf einer lokalen TTF-Schriftart.
Zusätzlich wird ein SVG mit einem blauen Rechteck erzeugt.

Voraussetzungen:
- fonttools: pip install fonttools
- svgwrite: pip install svgwrite
"""

# Importiere benötigte Module
from fontTools.ttLib import TTFont           # Zum Laden der TTF-Schriftart
from fontTools.pens.svgPathPen import SVGPathPen  # Zum Erzeugen der SVG-Pfade
import svgwrite  # Zum Erzeugen eines SVG mit einem Rechteck

def text_to_svg(font_path, text, output_svg):
    """
    Konvertiert den angegebenen Text in SVG-Pfade basierend auf der TTF-Schriftart.
    Das finale SVG-Dokument wird in die Datei 'output_svg' geschrieben.
    """
    # Lade die TTF-Schriftart aus dem lokalen Dateisystem
    font = TTFont(font_path)
    glyphSet = font.getGlyphSet()  # Extrahiere das Glyphen-Set
    cmap = font["cmap"].getBestCmap()  # Mapping von Unicode-Codepunkten zu Glyphennamen
    hmtx = font["hmtx"].metrics  # Horizontale Metriken (z.B. Advance-Width)

    # Abrufen der Schriftmetriken
    ascent = font["hhea"].ascent  # Aufstiegswert (positiv)
    descent = font["hhea"].descent  # Abstiegswert (meist negativ)

    current_x = 0  # Startposition für die Platzierung der Glyphen
    paths = []  # Liste zur Speicherung der SVG <path>-Elemente

    # Verarbeite jeden Buchstaben im Text
    for char in text:
        codepoint = ord(char)  # Bestimme den Unicode-Codepunkt des Zeichens
        if codepoint not in cmap:
            print(f"Warnung: Zeichen '{char}' nicht in der Schriftart gefunden.")
            continue  # Überspringe Zeichen, die nicht in der Schriftart enthalten sind
        glyph_name = cmap[codepoint]  # Hole den Glyphennamen für das Zeichen
        glyph = glyphSet[glyph_name]  # Greife auf das entsprechende Glyph zu

        # Erzeuge den SVG-Pfad für das Glyph
        pen = SVGPathPen(glyphSet)  # Initialisiere den SVGPathPen
        glyph.draw(pen)  # Zeichne das Glyph mit dem Pen
        path_data = pen.getCommands()  # Erhalte die SVG-Pfadbefehle

        # Hole die Advance-Width (Platzbedarf) für das Glyph
        advance_width = hmtx[glyph_name][0]

        # Erzeuge ein SVG <path>-Element mit einer Translation basierend auf der aktuellen x-Position
        path_element = f'<path d="{path_data}" transform="translate({current_x}, 0)" />'
        paths.append(path_element)  # Füge das Element zur Liste hinzu

        current_x += advance_width  # Erhöhe die x-Position für das nächste Glyph

    total_width = current_x  # Gesamte Breite des Textes

    # Erzeuge den Inhalt des SVG-Dokuments
    svg_content = f'''<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="{ascent - descent}" viewBox="0 {descent} {total_width} {ascent - descent}">
  <!-- Gruppe zur Transformation der y-Achse, damit der Text korrekt ausgerichtet wird -->
  <g transform="translate(0, {ascent}) scale(1, -1)">
    {" ".join(paths)}
  </g>
</svg>
'''

    # Schreibe den SVG-Inhalt in die Ausgabedatei
    with open(output_svg, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"SVG wurde erfolgreich erstellt: {output_svg}")

def create_rectangle_svg():
    """
    Erzeugt eine SVG-Datei mit einem blauen Rechteck und einer schwarzen Kontur.
    """
    # Erstellen der SVG-Datei mit Millimetern als Maßeinheit
    dwg = svgwrite.Drawing('rectangle.svg', profile='tiny', size=('61.8mm', '61.8mm'))

    # Hinzufügen des Rechtecks mit blauer Füllung und schwarzer Kontur von 1mm
    dwg.add(dwg.rect(insert=(0, 0), size=('61.8mm', '61.8mm'), fill='blue', stroke='black', stroke_width='1mm'))

    # Speichern der SVG-Datei
    dwg.save()
    print(f"SVG mit einem Rechteck von 61,8mm x 61,8mm und einer schwarzen Kontur von 1mm wurde als 'rectangle.svg' gespeichert.")

def main():
    """
    Hauptfunktion: Hier werden die Parameter fest definiert.
    Passe einfach den Text in der Variable 'text' an.
    """
    # Erstelle das Rechteck SVG
    create_rectangle_svg()

    # Pfad zur lokalen TTF-Schriftart (raw string, um Backslashes zu berücksichtigen)
    font_path = r"C:\Users\erikw\Downloads\Sniglet-Regular.ttf"
    
    # Text, der in SVG konvertiert werden soll
    text = "Hallo Welt"
    
    # Name der Ausgabedatei
    output_svg = "output.svg"
    
    # Starte die Konvertierung von Text zu SVG
    text_to_svg(font_path, text, output_svg)

if __name__ == "__main__":
    main()
