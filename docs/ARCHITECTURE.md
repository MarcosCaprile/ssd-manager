# Architektur

## Leitentscheidungen

- Die Flutter-App ist ein API-first Client. Alle Rollenregeln werden in der UI nur gespiegelt; verbindlich entscheidet das PHP-Backend.
- Das Backend nutzt PDO Prepared Statements, HMAC-signierte Access-Tokens und gehashte Refresh-Tokens in `user_devices`.
- Schulen sind über `school_id` modelliert. Version 1 nutzt eine Schule, bleibt aber mandantenfähig.
- Diensttage sind lokale Kalendertage in `Europe/Berlin`; Zeitpunkte wie Login, Audit und Notifications werden serverseitig in UTC gespeichert.
- Dienstplanänderungen laufen transaktionssicher über `SELECT ... FOR UPDATE`.
- Firebase wird nur für Push-Benachrichtigungen genutzt. Geräteinformationen bleiben datensparsam.

## Flutter

Wichtige Module:

- `config`: API-URL und App-Konstanten
- `core/api`: HTTP-Client, Token-Refresh und Fehlerbehandlung
- `core/security`: sichere lokale Session
- `core/push`: defensive FCM-Initialisierung
- `repositories`: API-Zugriffe je Bereich
- `providers`: Riverpod-Provider und Auth-State
- `screens`: Login, Passwortwechsel, Dienstplan, Ankündigungen, Sani-Liste, Profil
- `utils/duty_rules.dart`: testbare 14-Tage-/48-Stunden-Regeln

## Backend

Wichtige Module:

- `public/index.php`: REST-Routen unter `/api/v1`
- `Core`: Config, Router, Request, Response, Validation, Database
- `Services`: Auth, User, Duty, Notifications, Firebase, Audit, Rate Limiting
- `Controllers`: schlanke REST-Controller

## Datenmodell

Tabellen:

- `schools`
- `users`
- `user_devices`
- `duty_days`
- `duty_assignments`
- `announcements`
- `notification_logs`
- `audit_logs`
- `login_attempts`

Die Migration liegt in `backend/database/migrations/001_initial_schema.sql`.

## Bekannte Version-1-Grenzen

- Es gibt genau einen gemeinsamen Ankündigungskanal.
- Keine offene Registrierung.
- Keine privaten Chats, Datei-Uploads, Standortdaten oder Telefonnummern.
- Profilbearbeitung durch Admins ist als API-Stelle vorgesehen, aber in Version 1 bewusst deaktiviert.
