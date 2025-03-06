#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modulares Python-Programm zur Konvertierung von Text in SVG-Pfade basierend auf einer lokalen TTF-Schriftart.
Zusätzlich kann ein SVG mit einem Rechteck erzeugt werden.

Voraussetzungen:
- fonttools: pip install fonttools
- svgwrite: pip install svgwrite

Start im interaktiven Modus:
   python main.py

Direkter Aufruf:
1. Text in SVG konvertieren:
   python main.py --font "Schriftart.ttf" --text "Hallo Welt"

2. Rechteck-SVG erzeugen:
   python main.py --rect --width 61.8 --height 61.8 --radius 15
"""

import argparse
import os
import svgwrite
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

def get_font_path(font_name: str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    font_dir = os.path.join(script_dir, "fonts")
    return os.path.join(font_dir, font_name)

def get_output_path(output_name: str) -> str:
    if os.path.dirname(output_name):
        return output_name
    script_dir = os.path.dirname(os.path.abspath(__file__))
    svg_dir = os.path.join(script_dir, "svg")
    os.makedirs(svg_dir, exist_ok=True)
    return os.path.join(svg_dir, output_name)

def list_fonts() -> list:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    font_dir = os.path.join(script_dir, "fonts")
    return [f for f in os.listdir(font_dir) if f.endswith(".ttf")]

def text_to_svg(font_name: str, text: str) -> None:
    font_path = get_font_path(font_name)
    output_svg = get_output_path(text[:24].replace(" ", "_") + ".svg")
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    cmap = font["cmap"].getBestCmap()
    hmtx = font["hmtx"].metrics
    ascent = font["hhea"].ascent
    descent = font["hhea"].descent

    current_x = 0
    paths = []

    for char in text:
        codepoint = ord(char)
        if codepoint not in cmap:
            print(f"Warnung: Zeichen '{char}' nicht in der Schriftart gefunden.")
            continue
        glyph_name = cmap[codepoint]
        glyph = glyph_set[glyph_name]
        pen = SVGPathPen(glyph_set)
        glyph.draw(pen)
        path_data = pen.getCommands()
        advance_width = hmtx[glyph_name][0]
        paths.append(f'<path d="{path_data}" transform="translate({current_x}, 0)" />')
        current_x += advance_width

    total_width = current_x
    svg_content = f'''<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="{ascent - descent}" viewBox="0 {descent} {total_width} {ascent - descent}">
  <g transform="translate(0, {ascent}) scale(1, -1)">
    {' '.join(paths)}
  </g>
</svg>
'''
    with open(output_svg, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"SVG wurde erfolgreich erstellt: {output_svg}")

def create_rectangle_svg(output_svg: str, width: float, height: float, corner_radius: float = 0) -> None:
    # Erstellen des Dateinamens unter Berücksichtigung der Abmessungen des Rechtecks
    rect_name = f"rect-B{width}xH{height}xR{corner_radius}"
    output_svg = get_output_path(rect_name + ".svg")
    
    # Umrechnung des Eckenradius von mm in Pixel
    radius_px = corner_radius * 3.7795
    
    # Erstellen des SVG-Dokuments
    dwg = svgwrite.Drawing(output_svg, profile='tiny', size=(f'{width}mm', f'{height}mm'))
    dwg.add(dwg.rect(insert=(0, 0), size=(f'{width}mm', f'{height}mm'),
                      fill='blue', stroke='black', stroke_width='1mm',
                      rx=radius_px, ry=radius_px))
    dwg.save()
    print(f"SVG mit Rechteck gespeichert: {output_svg}")

def interactive_mode() -> None:
    while True:
        print("Was möchtest du tun?")
        print("1: Text in SVG umwandeln")
        print("2: Rechteck-SVG erstellen")
        print("3: Beenden")
        choice = input("Eingabe (1/2/3): ").strip()

        if choice == "1":
            while True:
                fonts = list_fonts()
                if not fonts:
                    print("Keine Schriftarten im 'fonts'-Ordner gefunden.")
                    return
                print("Verfügbare Schriftarten:")
                for i, font in enumerate(fonts, 1):
                    print(f"{i}: {font}")
                font_choice = input("Wähle eine Schriftart (Nummer eingeben): ").strip()
                try:
                    font_name = fonts[int(font_choice) - 1]
                except (IndexError, ValueError):
                    print("Ungültige Auswahl.")
                    continue
                text = input("Gib den Text ein, der in SVG umgewandelt werden soll: ").strip()
                text_to_svg(font_name, text)
                if input("Neuen Text eingeben? (j/n): ").strip().lower() != "j":
                    break
        elif choice == "2":
            while True:
                width = float(input("Breite des Rechtecks (mm): ").strip())
                height = float(input("Höhe des Rechtecks (mm): ").strip())
                radius = float(input("Eckenradius (mm, optional): ").strip() or "0")
                create_rectangle_svg("rectangle.svg", width, height, radius)
                if input("Neues Rechteck erstellen? (j/n): ").strip().lower() != "j":
                    break
        elif choice == "3":
            break
        else:
            print("Ungültige Eingabe.")

if __name__ == "__main__":
    interactive_mode()
