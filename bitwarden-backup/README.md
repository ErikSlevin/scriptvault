# Bitwarden Backup Skript

Dieses PowerShell-Skript dient dazu, die Daten eines Bitwarden-Benutzers zu sichern, einschließlich der Anhänge, und sie in einem selbstgehosteten oder Standard-Bitwarden-Tresor zu exportieren. Es ermöglicht auch das Sichern der Anhänge und das Verschlüsseln des Backups.

## Voraussetzungen

- PowerShell 5.1 oder höher
- Bitwarden CLI: Installieren Sie das Bitwarden CLI-Tool gemäß den Anweisungen unten.

## Bitwarden CLI Installation

Stellen Sie sicher, dass Bitwarden und die erforderlichen Module in Ihrer PowerShell-Umgebung ordnungsgemäß installiert und konfiguriert sind, bevor Sie das Skript ausführen.

1. **Installieren Sie Chocolatey:** Chocolatey ist ein Paketmanager für Windows. Führen Sie den folgenden Befehl in einer erhöhten PowerShell-Konsole aus, um Chocolatey zu installieren:
   
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

2. **Installieren Sie Bitwarden CLI:** Verwenden Sie den folgenden Befehl, um Bitwarden CLI mit Chocolatey zu installieren:

   ```powershell
   choco install bitwarden-cli
   ```

3. **Installieren Sie das 7zip4PowerShell-Modul:** Verwenden Sie den folgenden Befehl in PowerShell, um das 7zip4PowerShell-Modul zu installieren:

   ```powershell
   Install-Module -Name 7Zip4Powershell
   ```

### Beispielkonfigurationsdatei (`config.ini`)

```ini
[Secrets]
server=selfhosted-bitwarden.server.com
backupFolder=C:\my-backup-folder\Bitwarden

[Users]
emails=bitwarden-user-1@gmx.de,bitwarden-user-2@outlook.de,bitwarden-user-3@gmail.de
```

