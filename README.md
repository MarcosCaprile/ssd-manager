# SSD Manager

SSD Manager ist eine mobile App für den Schulsanitätsdienst einer Schule. Die App digitalisiert den Dienstplan, Ankündigungen, Sani-Liste, Profile, Geräteverwaltung und Verwaltungsfunktionen für Schulsanitäter, Sani-Leitung, Lehreraufsicht und Sekretariat.

## Stack

- Flutter/Dart mit gemeinsamer Codebasis für Android und iOS
- PHP 8.2+ Backend ohne Composer-Pflicht
- MySQL/MariaDB mit phpMyAdmin-kompatiblem Schema
- REST-API unter `/api/v1`
- Railway-Deployment per Dockerfile mit MySQL im selben Projekt
- Firebase Cloud Messaging für Push-Benachrichtigungen
- Sichere lokale Sitzungsspeicherung über `flutter_secure_storage`

## Projektstruktur

- `lib/`: Flutter-App mit `config`, `core`, `models`, `providers`, `repositories`, `screens`, `themes`, `utils`, `widgets`
- `backend/public`: Webroot für das PHP-Backend
- `backend/src`: PHP-Router, Controller und Services
- `backend/database`: Migrationen und Seed-Daten
- `backend/cron`: geplante Backend-Jobs
- `backend/scripts`: CLI-Helfer, z. B. erster Lehreraccount
- `docs`: Architektur, API, Rollen, Sicherheit, Deployment und Firebase

## Lokaler Start

1. MySQL-Datenbank erstellen, z. B. `ssd_manager`.
2. `php backend/scripts/migrate.php` ausführen, damit alle versionierten
   Migrationen in Reihenfolge angewendet werden.
3. Optional `backend/database/seeds/seed.sql` ausführen. Testpasswort der Seed-Accounts: `password`.
4. `backend/.env.example` nach `backend/.env` kopieren und Werte setzen.
5. Backend starten:

```bash
php -S localhost:8080 -t backend/public
```

6. Flutter-App starten:

```bash
flutter pub get
flutter run --dart-define=SSD_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Für ein echtes Gerät muss `SSD_API_BASE_URL` auf die erreichbare Backend-URL zeigen.

## Erster Lehreraccount

Nach Migration und `.env` zuerst die Schule anlegen:

```bash
php backend/scripts/create_school.php "Name der Schule" schul-slug
```

Danach muss `DEFAULT_SCHOOL_ID` auf die ausgegebene ID zeigen. Anschließend den
ersten Lehreraccount anlegen:

```bash
php backend/scripts/create_teacher.php Lena Muster lehrer lena.muster@example.edu "SehrSicheresStartpasswort!"
```

Der Account erhält `must_change_password = true` und muss beim ersten Login das Passwort ändern.

## Railway

`Dockerfile` und `railway.json` bereiten die PHP-API für Railway vor. Vor jedem
Deployment wird das Schema mit `php scripts/migrate.php` angewendet; anschließend
prüft Railway `/api/v1/health`. Die vollständige Einrichtung und die benötigten
Variablen stehen in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Firebase

1. Firebase-Projekt erstellen.
2. Android-App mit Package `com.minutmate.ssdmanager` registrieren.
3. iOS-App mit Bundle ID `com.minutmate.ssdmanager` registrieren.
4. `google-services.json` nach `android/app/` legen.
5. `GoogleService-Info.plist` nach `ios/Runner/` legen.
6. Service-Account-JSON auf dem Server außerhalb des Webroots speichern.
7. In `backend/.env` setzen:

```env
FCM_ENABLED=true
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=<base64-codiertes-service-account-json>
FIREBASE_PROJECT_ID=your-project-id
```

Für lokale Entwicklung kann stattdessen weiterhin
`FIREBASE_SERVICE_ACCOUNT=/secure/path/firebase-service-account.json` verwendet
werden. Das echte JSON und sein Base64-Inhalt dürfen niemals committed werden.

Details stehen in [docs/FIREBASE.md](docs/FIREBASE.md).

## Cronjobs

Der Backend-Job markiert vergangene geplante Dienste als absolviert und sendet 48-Stunden-Erinnerungen:

```bash
php backend/cron/run_due_jobs.php
```

Empfohlener Cron:

```cron
*/15 * * * * /usr/bin/php /var/www/ssd-manager/backend/cron/run_due_jobs.php >/dev/null 2>&1
```

## Builds

Android:

```bash
flutter build apk --release --dart-define=SSD_API_BASE_URL=https://example.org/api/v1
flutter build appbundle --release --dart-define=SSD_API_BASE_URL=https://example.org/api/v1
```

Für einen Debug-Test auf einem echten Android-Gerät im gleichen WLAN zuerst das Backend im lokalen Netz starten und anschließend die aktuelle WLAN-IP des Macs einsetzen:

```bash
php -S 0.0.0.0:8080 -t backend/public
flutter build apk --debug --dart-define=SSD_API_BASE_URL=http://<MAC-IP>:8080/api/v1
```

Lokales HTTP ist nur im Android-Debug-Build erlaubt. Release-Builds müssen eine HTTPS-Backend-URL verwenden.

iOS:

```bash
flutter build ios --release --dart-define=SSD_API_BASE_URL=https://example.org/api/v1
```

Die iOS-Mindestversion ist 15.0. Diese plattformspezifische Vorgabe ändert die Android-Unterstützung der gemeinsamen Flutter-Codebasis nicht.

## Tests und Checks

```bash
flutter analyze
flutter test
php backend/tests/run.php
```

Für den lokalen API-Smoke-Test müssen Migration und Demo-Seeds eingespielt sein. Während das Backend läuft, in einem zweiten Terminal ausführen:

```bash
php backend/tests/api_smoke.php
php backend/tests/api_write_smoke.php
php backend/tests/api_bulk_smoke.php
php backend/tests/api_duty_management_smoke.php
php backend/tests/api_attachment_smoke.php
php backend/tests/api_secretariat_smoke.php
php backend/tests/api_security_smoke.php
```

Der Write-Smoke-Test ist auf eine lokale API und lokale Datenbank beschränkt. Er erstellt einen eindeutig benannten Testaccount und räumt alle dabei erzeugten Testdaten anschließend wieder auf.

Der Parallelitätstest benötigt zwei gleichzeitig laufende Backendprozesse auf Port 8080 und 8081:

```bash
php -S localhost:8081 -t backend/public
php backend/tests/api_concurrency_smoke.php
```

Auf diesem Entwicklungsrechner sind Flutter-Analyse und Flutter-Tests lauffähig. PHP ist für lokale PHP-Tests im PATH erforderlich.

## Weitere Dokumentation

- [Architektur](docs/ARCHITECTURE.md)
- [Rollenmatrix](docs/ROLES.md)
- [API-Endpunkte](docs/API.md)
- [Sicherheit und Datenschutz](docs/SECURITY_PRIVACY.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Firebase](docs/FIREBASE.md)
