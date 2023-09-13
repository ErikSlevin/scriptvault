# Inhaltsverzeichnis

- [Deutsch](#Deutsch)
- [English](#English)

# Deutsch

Dieses Skript ermöglicht die Erstellung von Backups für verschiedene Anwendungen und Dateien. Es unterstützt die Komprimierung von Ordnern, das Verschieben von Dateien, das Kopieren von Remote-Daten und das Protokollieren von Backup-Vorgängen.

## Funktionen

- **Set-Password**: Diese Funktion ermöglicht die Eingabe eines sicheren Passworts gemäß bestimmter Kriterien.
- **LogEntry**: Schreibt einen Eintrag in eine MySQL-Datenbank, um Backup-Aktivitäten zu protokollieren.
- **Backup-Folder**: Komprimiert einen Ordner in ein 7zip-Archiv und speichert es an einem bestimmten Speicherort.
- **Move-BackupFiles**: Sucht nach Dateien an einem bestimmten Speicherort, kopiert oder verschiebt sie in ein Zielverzeichnis und benennt sie entsprechend um.
- **Copy-RemoteData**: Kopiert Daten von einem Remote-Server auf den lokalen Computer mithilfe des SCP-Protokolls.
- **Ausgabe**: Zeigt eine Liste von verfügbaren Backup-Optionen im Hauptmenü an.
- **ShowMainMenu**: Das Hauptmenü, das dem Benutzer ermöglicht, Backup-Optionen auszuwählen und auszuführen.

## Verwendung

1. Das Skript muss auf dem Computer ausgeführt werden, auf dem die Backups erstellt werden sollen.
2. Konfigurieren Sie die gewünschten Backup-Optionen im Skript, indem Sie die entsprechenden Variablen im Abschnitt "Backup-Konfiguration" anpassen.
3. Führen Sie das Skript aus und wählen Sie die gewünschte Backup-Option aus dem Hauptmenü aus.
4. Befolgen Sie die Anweisungen im Skript, um den Backup-Vorgang abzuschließen.

## Voraussetzungen

- PowerShell 5.1 oder höher
- MySQL-Datenbank für die Protokollierung (mit der erforderlichen Datenbankstruktur)
- 7-Zip installiert und im Systempfad verfügbar

Bitte beachten Sie, dass das Skript entsprechend Ihren Anforderungen und Umgebungen angepasst werden muss. Stellen Sie sicher, dass Sie die erforderlichen Berechtigungen und Zugriffsrechte für die Durchführung von Backup-Operationen haben.

# English

This script allows you to create backups for various applications and files. It supports compressing folders, moving files, copying remote data, and logging backup operations.

## Features

- **Set-Password**: This function allows you to enter a secure password that meets specific criteria.
- **LogEntry**: Writes an entry to a MySQL database to log backup activities.
- **Backup-Folder**: Compresses a folder into a 7zip archive and saves it to a specified location.
- **Move-BackupFiles**: Searches for files at a specified location, copies or moves them to a destination directory, and renames them accordingly.
- **Copy-RemoteData**: Copies data from a remote server to the local computer using the SCP protocol.
- **Output**: Displays a list of available backup options in the main menu.
- **ShowMainMenu**: The main menu that allows the user to select and execute backup options.

## Usage

1. The script needs to be run on the computer where the backups are to be created.
2. Configure the desired backup options in the script by adjusting the respective variables in the "Backup Configuration" section.
3. Run the script and select the desired backup option from the main menu.
4. Follow the instructions in the script to complete the backup process.

## Requirements

- PowerShell 5.1 or higher
- MySQL database for logging (with the required database structure)
- 7-Zip installed and available in the system path

Please note that the script needs to be customized according to your requirements and environments. Ensure that you have the necessary permissions and access rights to perform backup operations.
