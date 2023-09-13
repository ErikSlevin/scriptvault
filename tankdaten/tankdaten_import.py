import argparse
import subprocess
import mysql.connector
from datetime import datetime
from mysql.connector import Error

# Überprüfen, ob das mysql.connector-Modul installiert ist
try:
    mysql.connector.connect()
except ImportError:
    print("\033[91mFehler: Das mysql.connector-Modul ist nicht installiert.\033[0m")
    print("Bitte installieren Sie es mit folgendem Befehl:")
    print("    \033[94mpip install mysql-connector-python\033[0m")
    exit(1)

# Überprüfen, ob pip installiert ist
try:
    subprocess.check_output(["pip", "--version"])
except FileNotFoundError:
    print("\033[91mFehler: pip ist nicht installiert.\033[0m")
    print("Bitte installieren Sie pip mit den Anweisungen für Ihr Betriebssystem unter")
    print("    \033[94mhttps://pip.pypa.io/en/stable/installation/\033[0m")
    exit(1)

# Funktion zum Ermitteln der IP-Adresse des MariaDB-Containers
def get_mariadb_container_ip(container_name):
    try:
        result = subprocess.check_output(['docker', 'inspect', '-f', '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}', container_name])
        return result.decode().strip()
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Abrufen der IP-Adresse des Containers: {e}")
        exit(1)

# Ermitteln Sie die IP-Adresse des MariaDB-Containers
mariadb_container_name = 'mariadb'
mariadb_ip = get_mariadb_container_ip(mariadb_container_name)

# Konfigurationsdaten für die MySQL-Datenbank
host = '10.0.0.21'  # Der Host der MySQL-Datenbank
user = 'fuellogger'  # Der MySQL-Benutzername
password = 'P@ssw0rd'  # Das MySQL-Passwort
database_name = 'db_fuellogger'  # Der Name der MySQL-Datenbank

# Funktion zum Erstellen der Tabellen, falls sie nicht existieren
def create_tables_if_not_exist(host, user, password, database_name):
    try:
        connection = mysql.connector.connect(host=host, user=user, password=password, database=database_name)
        cursor = connection.cursor()

        # SQL-Befehl zum Erstellen der Tabelle, wenn sie nicht existiert
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tbl_tankungen (
                id INT AUTO_INCREMENT PRIMARY KEY,
                datum DATE,
                liter DECIMAL(10, 2),
                literpreis DECIMAL(10, 2),
                gesamtpreis DECIMAL(10, 2)
            );
        """)

        cursor.close()
        connection.close()
    except Error as e:
        print("\033[91mFehler beim Zugriff auf die Datenbank:\033[0m")
        print("Bitte führen Sie die folgenden Schritte manuell aus, um die Datenbank und den Benutzer zu erstellen:")
        print("# Schritt 1 #")
        print("Erstellen Sie die Datenbank:")
        print(f"SQL Befehl: CREATE DATABASE {database_name};")
        print()
        print("# Schritt 2 #")
        print("Erstellen Sie den Benutzer:")
        print(f"SQL Befehl: CREATE USER '{user}'@'%' IDENTIFIED BY '{password}';")
        print()
        print("# Schritt 3 #")
        print("Gewähren Sie dem Benutzer Berechtigungen:")
        print(f"SQL Befehl: GRANT INSERT, UPDATE, DELETE, SELECT ON {database_name}.* TO '{user}'@'%';")
        print()
        print("# Schritt 4 #")
        print("Aktualisieren Sie die Berechtigungen:")
        print("SQL Befehl: FLUSH PRIVILEGES;")
        exit(1)

# Funktion zum Einfügen von Daten aus einer CSV-Datei
def insert_data_from_csv(host, user, password, database_name, csv_file):
    try:
        connection = mysql.connector.connect(host=host, user=user, password=password, database=database_name)
        cursor = connection.cursor()

        with open(csv_file, 'r') as file:
            lines = file.readlines()
            for line in lines[1:]:
                line = line.replace(',', '.')
                line = line.replace(' €', '€')
                data = line.strip().split(';')
                if len(data) != 3:
                    print(f"Fehlerhafte Zeile in CSV: {line}")
                    continue
                datum, liter, literpreis = data

                datum = datetime.strptime(datum, '%d.%m.%Y').strftime('%Y-%m-%d')

                # Überprüfen, ob Daten mit dem gleichen Datum bereits in der Datenbank vorhanden sind
                cursor.execute("SELECT id FROM tbl_tankungen WHERE datum = %s", (datum,))
                existing_data = cursor.fetchone()

                if not existing_data:
                    liter = round(float(liter), 2)
                    literpreis = round(float(literpreis.replace('€', '').replace(',', '.')), 2)
                    gesamtpreis = round(liter * literpreis, 2)

                    cursor.execute("""
                        INSERT INTO tbl_tankungen (datum, liter, literpreis, gesamtpreis)
                        VALUES (%s, %s, %s, %s);
                    """, (datum, liter, literpreis, gesamtpreis))

        connection.commit()
        cursor.close()
        connection.close()
    except Error as e:
        print("\033[91mFehler beim Einfügen der Daten:\033[0m", e)
        exit(1)

def main():
    parser = argparse.ArgumentParser(description='CSV-Daten in MariaDB-Datenbank importieren')
    parser.add_argument('--csvfile', type=str, required=True, help='CSV-Datei mit Tankdaten')
    args = parser.parse_args()

    create_tables_if_not_exist(host, user, password, database_name)
    insert_data_from_csv(host, user, password, database_name, args.csvfile)

if __name__ == '__main__':
    main()
