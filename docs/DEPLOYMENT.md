# Deployment

## Zielplattform

Die produktive Zielarchitektur ist Railway mit zwei Services in einem eigenen
`SSD Manager`-Projekt:

- `ssd-api`: PHP/Apache-API aus diesem GitHub-Repository
- `MySQL`: MySQL-Datenbank im selben Railway-Projekt

API und Datenbank sollen in derselben EU-Region betrieben werden. Für deutsche
Schuldaten ist bei Railway `EU West (Amsterdam)` die naheliegende Auswahl. Das
leere All-Inkl-Schema ist nicht mehr die geplante Laufzeitdatenbank.

Das Repository enthält dafür:

- `Dockerfile` für PHP 8.4 mit Apache, PDO MySQL, cURL und mbstring
- `railway.json` mit Pre-Deploy-Migration, Healthcheck und Restart-Policy
- `backend/scripts/migrate.php` für die idempotente initiale Migration
- `GET /api/v1/health` als datenbankgestützten Deployment-Healthcheck

## Voraussetzungen

- PHP 8.2+ mit PDO MySQL, OpenSSL und cURL
- MySQL 8 oder MariaDB mit InnoDB
- Webserver mit Rewrite auf `backend/public/index.php`
- HTTPS-Zertifikat
- phpMyAdmin optional zur Datenbankverwaltung
- Flutter SDK für App-Builds

## Railway-Erstdeployment

1. Im bestehenden Railway-Workspace ein separates leeres Projekt namens
   `SSD Manager` anlegen. StudyConnect bleibt ein unabhängiges Projekt.
2. Einen MySQL-Service hinzufügen und für ihn `EU West (Amsterdam)` auswählen.
3. Einen Service `ssd-api` aus dem GitHub-Repository
   `MarcosCaprile/ssd-manager` und dem vorgesehenen Deployment-Branch anlegen.
4. Auch für `ssd-api` `EU West (Amsterdam)` auswählen.
5. Im API-Service folgende Variablen setzen. `MySQL` muss bei abweichendem
   Service-Namen entsprechend ersetzt werden:

```env
APP_ENV=production
APP_DEBUG=false
API_BASE_PATH=/api/v1
DB_HOST=${{MySQL.MYSQLHOST}}
DB_PORT=${{MySQL.MYSQLPORT}}
DB_DATABASE=${{MySQL.MYSQLDATABASE}}
DB_USERNAME=${{MySQL.MYSQLUSER}}
DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}
DB_CHARSET=utf8mb4
JWT_SECRET=<LANGER-ZUFAELLLIGER-GEHEIMWERT>
ACCESS_TOKEN_TTL_SECONDS=900
REFRESH_TOKEN_TTL_DAYS=90
DEFAULT_SCHOOL_ID=1
SCHOOL_TIMEZONE=Europe/Berlin
DUTY_CAPACITY=3
RATE_LIMIT_LOGIN_ATTEMPTS=8
RATE_LIMIT_LOGIN_WINDOW_MINUTES=15
FCM_ENABLED=false
```

6. Im API-Service eine öffentliche Railway-Domain erzeugen. Railway stellt
   HTTPS automatisch bereit. Der Healthcheck läuft unter `/api/v1/health`.
7. Beim Deployment führt Railway vor dem Start automatisch
   `php scripts/migrate.php` aus. Das Deployment wird nur aktiv, wenn danach
   der Healthcheck inklusive Datenbankverbindung erfolgreich ist.
8. Nach dem ersten erfolgreichen Deployment per Railway-SSH zunächst die reale
   Schule und anschließend den ersten Lehreraccount anlegen:

```bash
php scripts/create_school.php "Name der Schule" schul-slug
php scripts/create_teacher.php Lena Muster lehrer lena.muster@example.edu "SehrSicheresStartpasswort!"
```

Die ausgegebene Schul-ID muss mit `DEFAULT_SCHOOL_ID` übereinstimmen. Keine
Demo-Seeds und keine echten Zugangsdaten in Git einchecken.

## Railway-Cronjob

Für `backend/cron/run_due_jobs.php` wird später ein separater Railway-Service
aus demselben Image benötigt. Er erhält dieselben Datenbank- und
Firebase-Variablen, den Startbefehl `php cron/run_due_jobs.php` und einen
passenden Cron-Zeitplan. Der Web-Service selbst bleibt dauerhaft aktiv.

## Backend installieren

Die folgenden Schritte gelten für ein generisches PHP-Hosting außerhalb von
Railway:

1. Projekt auf den Server kopieren.
2. Webroot auf `backend/public` setzen.
3. Datenbank und Datenbanknutzer anlegen.
4. Migration ausführen:

```bash
mysql -u ssd_manager -p ssd_manager < backend/database/migrations/001_initial_schema.sql
```

5. `.env` aus `.env.example` erstellen.
6. `JWT_SECRET` mit einem langen Zufallswert setzen.
7. Erste Schule und danach den ersten Lehreraccount per CLI erstellen.
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
