# Inhaltsverzeichnis

- [Deutsch](#Deutsch)
- [English](#English)

## Deutsch

Dieses Skript ermöglicht die Suche nach aktiven Hosts innerhalb eines IP-Adressbereichs. Es versucht, die IP-Adressen im angegebenen Bereich zu pingen und die MAC-Adressen und Hostnamen der erreichbaren Hosts zu ermitteln. Die Ergebnisse werden in einer Log-Datei gespeichert.

### Verwendung
1. Geben Sie die Start- und End-IP-Adressen im Skript an:
```powershell
$startIPString = "10.0.0.0"
$endIPString = "10.0.0.90"
```
2. Führen Sie das Skript mit PowerShell aus: `.\ip_scan.ps1`
3. Das Skript durchläuft den IP-Adressbereich und gibt Informationen zu den erreichbaren Hosts aus.
4. Die Ergebnisse werden in einer Log-Datei gespeichert, die auf dem Desktop gespeichert ist.

**Hinweis:** Stellen Sie sicher, dass Sie über die erforderlichen Berechtigungen verfügen, um Hosts zu pingen und Informationen zu deren MAC-Adressen und Hostnamen abzurufen.

### Hinweise
- Das Skript kann eine Weile dauern, je nach Größe des IP-Adressbereichs und der Netzwerkkonnektivität.
- Überprüfen Sie die Log-Datei, um die gefundenen Hosts, deren MAC-Adressen und Hostnamen anzuzeigen.
- Es wird empfohlen, das Skript mit Administratorrechten auszuführen, um die Genauigkeit der Ergebnisse zu verbessern.

## English

This script allows you to search for active hosts within a range of IP addresses. It attempts to ping the IP addresses within the specified range and retrieve the MAC addresses and hostnames of reachable hosts. The results are saved in a log file.

### Usage
1. Specify the start and end IP addresses in the script:
```powershell
$startIPString = "10.0.0.0"
$endIPString = "10.0.0.90"
```
2. Run the script using PowerShell: `.\ip_scan.ps1`
3. The script will iterate through the IP address range and display information about the reachable hosts.
4. The results will be saved in a log file located on the desktop.

**Note:** Ensure that you have the necessary permissions to ping hosts and retrieve their MAC addresses and hostnames.

### Notes
- The script may take some time to run, depending on the size of the IP address range and network connectivity.
- Check the log file to view the discovered hosts, their MAC addresses, and hostnames.
- It is recommended to run the script with administrator privileges to improve the accuracy of the results.
