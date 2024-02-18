### Bitwarden Password Manager Backup Script (One or Multi Accounts)

---

**English Description:**

This script provides a convenient way to back up Bitwarden password manager data for two accounts. It exports both account data and attachments securely to your specified backup location.

#### Configurations:

- **Server:** Enter the URL of your self-hosted Bitwarden server or leave it blank to use the default Bitwarden server.
- **Backup Folder:** Specify the directory where you want to store the backups.
- **User:** Provide the usernames of the Bitwarden accounts you want to back up.
- **Extension:** Define the file extension for the backup files (e.g., "json" for JSON format).

#### Usage:

1. Configure the script by providing the server URL, backup folder path, usernames, and file extension.
2. Run the script in PowerShell.
3. Enter the master passwords for each user when prompted.
4. The script will sync the Bitwarden vault, export the data, secure attachments, and save them to the specified backup folder.

---

**Deutsche Beschreibung:**

Dieses Skript bietet eine bequeme Möglichkeit, Daten des Bitwarden-Passwortmanagers für einen oder mehrere Konten zu sichern. Es exportiert sowohl die Kontodaten als auch Anlagen sicher in den angegebenen Backup-Ordner.

#### Konfigurationen:

- **Server:** Geben Sie die URL Ihres selbst gehosteten Bitwarden-Servers ein oder lassen Sie das Feld leer, um den Standard-Bitwarden-Server zu verwenden.
- **Backup-Ordner:** Geben Sie das Verzeichnis an, in dem Sie die Backups speichern möchten.
- **Benutzer:** Geben Sie die Benutzernamen der Bitwarden-Konten an, die Sie sichern möchten.
- **Erweiterung:** Definieren Sie die Dateierweiterung für die Backup-Dateien (z. B. "json" für das JSON-Format).

#### Verwendung:

1. Konfigurieren Sie das Skript, indem Sie die Server-URL, den Backup-Ordnerpfad, die Benutzernamen und die Dateierweiterung angeben.
2. Führen Sie das Skript in PowerShell aus.
3. Geben Sie bei Aufforderung die Masterpasswörter für jeden Benutzer ein.
4. Das Skript synchronisiert den Bitwarden-Tresor, exportiert die Daten, sichert Anhänge und speichert sie im angegebenen Backup-Ordner.

---

Bitte beachten Sie: Stellen Sie sicher, dass Bitwarden und die erforderlichen Module in Ihrer PowerShell-Umgebung ordnungsgemäß installiert und konfiguriert sind, bevor Sie das Skript ausführen.

* https://chocolatey.org/install
* Run Powershell as Admin: ```Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))```
* ```choco install bitwarden-cli```