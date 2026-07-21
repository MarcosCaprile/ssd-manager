# SSD Manager

SSD Manager ist eine mobile App für den Schulsanitätsdienst einer Schule. Die App digitalisiert den Dienstplan, Ankündigungen, Sani-Liste, Profile, Geräteverwaltung und Verwaltungsfunktionen für Sani-Leitung und Lehreraufsicht.

## Stack

- Flutter/Dart mit gemeinsamer Codebasis für Android und iOS
- PHP 8.2+ Backend ohne Composer-Pflicht
- MySQL/MariaDB mit phpMyAdmin-kompatiblem Schema
- REST-API unter `/api/v1`
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
2. `backend/database/migrations/001_initial_schema.sql` ausführen.
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

Nach Migration und `.env`:

```bash
php backend/scripts/create_teacher.php Lena Muster lehrer lena.muster@example.edu "SehrSicheresStartpasswort!"
```

Der Account erhält `must_change_password = true` und muss beim ersten Login das Passwort ändern.

## Firebase

1. Firebase-Projekt erstellen.
2. Android-App mit Package `de.schule.ssdmanager` registrieren.
3. iOS-App mit passender Bundle ID registrieren.
4. `google-services.json` nach `android/app/` legen.
5. `GoogleService-Info.plist` nach `ios/Runner/` legen.
6. Service-Account-JSON auf dem Server außerhalb des Webroots speichern.
7. In `backend/.env` setzen:

```env
FCM_ENABLED=true
FIREBASE_SERVICE_ACCOUNT=/secure/path/firebase-service-account.json
FIREBASE_PROJECT_ID=your-project-id
```

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

iOS:

```bash
flutter build ios --release --dart-define=SSD_API_BASE_URL=https://example.org/api/v1
```

## Tests und Checks

```bash
flutter analyze
flutter test
php backend/tests/run.php
```

Auf diesem Entwicklungsrechner sind Flutter-Analyse und Flutter-Tests lauffähig. PHP ist für lokale PHP-Tests im PATH erforderlich.

## Weitere Dokumentation

- [Architektur](docs/ARCHITECTURE.md)
- [Rollenmatrix](docs/ROLES.md)
- [API-Endpunkte](docs/API.md)
- [Sicherheit und Datenschutz](docs/SECURITY_PRIVACY.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Firebase](docs/FIREBASE.md)
