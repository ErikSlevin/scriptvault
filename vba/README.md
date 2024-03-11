# Betrag in Worten Excel Funktion - [BetragInWorten.bas](BetragInWorten.bas)


Mit dieser Excel-Funktion können Sie nun Beträge in Ihrem Arbeitsblatt einfach in verständliche Worte umwandeln, was besonders nützlich ist, wenn Sie komplexe Finanzdaten präsentieren oder bearbeiten oder Rechnungen/Quittungen ausstellen möchten.

Um die Funktion zur Umwandlung eines Betrags in Worte in Excel nutzen zu können, folgen Sie bitte den untenstehenden Anweisungen:

1. Öffnen Sie Ihr Excel-Dokument.
2. Gehen Sie zum Menüband und klicken Sie auf "Entwicklertools".
3. Wählen Sie "Visual Basic" aus, um den Visual Basic for Applications (VBA)-Editor zu öffnen.
4. Fügen Sie ein neues Modul hinzu, falls noch nicht vorhanden.
5. Kopieren Sie den Code aus der Datei [BetragInWorten.bas](BetragInWorten.bas) und fügen Sie ihn in das neue Modul ein
6. Speichern Sie das Modul und schließen Sie den VBA-Editor.
7. Kehren Sie zu Excel zurück und verwenden Sie die Funktion ```=InWorten(ZELLE)```, um Beträge in Worte umzuwandeln.
Zum Beispiel:

Geben Sie den gewünschten Betrag in Zahlen in Zelle A1 ein, z.B. "221,11" für 221,11 Euro.
In Zelle A2 verwenden Sie die Formel =InWorten(A1). in A1 steht dann "Zweihundertundeinundzwanzig Euro und Elf Cent"

Quellen:

- [Sulprobil - Spell Number](https://www.sulprobil.com/sbspellnumber_en/)
- [Herber Forum - Zahlen in Worte Excel VBA](https://www.herber.de/forum/archiv/1744to1748/1744401_Zahlen_in_Worte_Excel_VBA.html)


# Datum und Autor des letzten Speicherns [last_change_and_author.bas](last_change_and_author.bas)

Dieses Excel-VBA-Modul enthält zwei Funktionen, die das Datum und die Uhrzeit des letzten Speicherns sowie den Namen des letzten Autors zurückgeben. Außerdem gibt es einen Workbook-Event-Handler, der sicherstellt, dass die Funktionen aktualisiert werden, wenn das Arbeitsblatt gespeichert wird.

## Funktionen

### LastSavedDateTime()
Gibt das Datum und die Uhrzeit des letzten Speicherns im Format "DD.MM.YY, HH:MM Uhr" zurück.

### LastAuthor()
Gibt den Namen des letzten Autors zurück, der das Arbeitsblatt gespeichert hat.

## Workbook-BeforeSave-Event-Handler

Der Workbook-BeforeSave-Event-Handler wird beim Speichern des Arbeitsblatts ausgelöst und aktualisiert alle Zellen, um sicherzustellen, dass die Funktionen LastSavedDateTime() und LastAuthor() mit den aktuellen Daten aktualisiert werden.

## Verwendung

1. Fügen Sie das Modul1 in Ihre Excel-Arbeitsmappe ein.
2. Verwenden Sie die Funktionen `=LastSavedDateTime()` und `=LastAuthor()` in Ihren Arbeitsblättern, um das Datum und die Uhrzeit des letzten Speicherns sowie den Namen des letzten Autors anzuzeigen.
3. Der Workbook-BeforeSave-Event-Handler wird automatisch aktiviert, sobald das Arbeitsblatt gespeichert wird, um sicherzustellen, dass die Funktionen aktualisiert werden.
