# Deployment

## Voraussetzungen

- PHP 8.2+ mit PDO MySQL, OpenSSL und cURL
- MySQL 8 oder MariaDB mit InnoDB
- Webserver mit Rewrite auf `backend/public/index.php`
- HTTPS-Zertifikat
- phpMyAdmin optional zur Datenbankverwaltung
- Flutter SDK für App-Builds

## Backend installieren

1. Projekt auf den Server kopieren.
2. Webroot auf `backend/public` setzen.
3. Datenbank und Datenbanknutzer anlegen.
4. Migration ausführen:

```bash
mysql -u ssd_manager -p ssd_manager < backend/database/migrations/001_initial_schema.sql
```

5. `.env` aus `.env.example` erstellen.
6. `JWT_SECRET` mit einem langen Zufallswert setzen.
7. Ersten Lehreraccount per CLI erstellen.
8. Cronjob für `backend/cron/run_due_jobs.php` einrichten.

## Webserver

Apache nutzt `backend/public/.htaccess`. Bei Nginx alle nicht existierenden Dateien an `index.php` weiterleiten.

## Produktionshinweise

- `APP_DEBUG=false`
- HTTPS erzwingen.
- Datenbanknutzer nur mit notwendigen Rechten ausstatten.
- Service-Account-Dateien außerhalb des Webroots speichern.
- Logs ohne Passwörter, Refresh-Tokens oder Firebase-Tokens führen.
- Backups für MySQL einrichten.
- `login_attempts` und technische Logs regelmäßig bereinigen.

## App-Konfiguration

Die API-URL wird beim Build gesetzt:

```bash
flutter build appbundle --release --dart-define=SSD_API_BASE_URL=https://ssd.example.org/api/v1
flutter build ios --release --dart-define=SSD_API_BASE_URL=https://ssd.example.org/api/v1
```
