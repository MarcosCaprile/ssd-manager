# Architektur

## Leitentscheidungen

- Die Flutter-App ist ein API-first Client. Alle Rollenregeln werden in der UI nur gespiegelt; verbindlich entscheidet das PHP-Backend.
- Das Backend nutzt PDO Prepared Statements, HMAC-signierte Access-Tokens und gehashte Refresh-Tokens in `user_devices`.
- Schulen sind über `school_id` modelliert. Version 1 nutzt eine Schule, bleibt aber mandantenfähig.
- Diensttage sind lokale Kalendertage in `Europe/Berlin`; Zeitpunkte wie Login, Audit und Notifications werden serverseitig in UTC gespeichert.
- Dienstplanänderungen laufen transaktionssicher über `SELECT ... FOR UPDATE`.
- Ein Diensttag trägt Kapazität, Namen und optionale Beschreibung sowie einen
  expliziten Ausfallstatus. Ausfallzeiträume werden als einzelne Werktage
  gespeichert. Normale Wochenenden bleiben unsichtbar; ausdrücklich benannte,
  manuell angelegte Wochenend-Events sind eine unterstützte Ausnahme.
- Ankündigungsanhänge werden für V1 als authentifiziert abrufbare BLOBs in
  MySQL gespeichert. Es entstehen keine öffentlichen Datei-URLs; Schule,
  Uploader, Nachricht, Typ und Größe werden serverseitig geprüft. Pro Uploader
  gelten transaktionssicher 100 MB. Beim Löschen eines versendeten Anhangs
  werden nur die Bytes entfernt; Nachricht und Tombstone bleiben sichtbar.
- Flutter rendert sichere, nutzerverständliche Fehler statt technischer
  Ausnahmen und unterstützt persistente System-/Hell-/Dunkel-Darstellung.
  Hauptpanels werden nach dem ersten Öffnen im `IndexedStack` erhalten;
  Vollbild-Ladeanzeigen erscheinen erst nach zwei Sekunden. Zentrale
  Riverpod-Revisionsprovider invalidieren betroffene Daten nach erfolgreichen
  Mutationen, Tabwechseln und App-Resume, ohne vorhandenen Inhalt zu entfernen.
  Der aktuell sichtbare Hauptbereich wird im Vordergrund zusätzlich alle vier
  Sekunden still abgeglichen; Push-Ereignisse aktualisieren Ankündigungen
  unmittelbar.
- Sani-Bulkdateien werden in Flutter als XLSX in ein explizites Mapping
  übersetzt, lokal und serverseitig geprüft und vom Backend ausschließlich
  vollständig innerhalb einer Transaktion angewendet.
- Eine zufällige `device_install_id` überlebt den Logout und erlaubt dem
  Backend, eine alte aktive Sitzung derselben App-Installation beim erneuten
  Login zu ersetzen.
- Firebase wird nur für Push-Benachrichtigungen genutzt. Android rendert
  normale Announcement-Datenpushes lokal als einen Inbox-Stack; iOS gruppiert
  sie über einen gemeinsamen APNs-Thread. Krankmeldungen verwenden auf beiden
  Plattformen einen davon getrennten dringenden Kanal/Thread.
  Geräteinformationen bleiben datensparsam.

## Flutter

Wichtige Module:

- `config`: API-URL und App-Konstanten
- `core/api`: HTTP-Client, Token-Refresh und Fehlerbehandlung
- `core/security`: sichere lokale Session
- `core/preferences`: vom Login unabhängige Geräteeinstellungen
- `core/files`: XLSX-Template, Import-Mapping und Export
- `core/push`: defensive FCM- und lokale Notification-Initialisierung
- `repositories`: API-Zugriffe je Bereich
- `providers`: Riverpod-Provider und Auth-State
- `screens`: Login, Passwortwechsel, Dienstplan, Ankündigungen, Sani-Liste,
  Profil und getrennte Profil-Unterseiten für Darstellung, Statistik, Geräte
  und Cloud-Dateien
- `utils/duty_rules.dart`: testbare 14-Tage-/48-Stunden-Regeln

## Backend

Wichtige Module:

- `public/index.php`: REST-Routen unter `/api/v1`
- `Core`: Config, Router, Request, Response, Validation, Database
- `Services`: Auth, User, transaktionale User-Bulkverwaltung, Duty,
  Ankündigungsanhänge, Notifications, Firebase, Audit, Rate Limiting
- `Controllers`: schlanke REST-Controller

## Datenmodell

Tabellen:

- `schools`
- `users`
- `user_devices`
- `duty_days`
- `duty_assignments`
- `announcements`
- `announcement_attachments`
- `notification_logs`
- `audit_logs`
- `login_attempts`
- `schema_migrations`

Versionierte Migrationen liegen in `backend/database/migrations`. Der
Migrations-Runner protokolliert angewendete Dateinamen in `schema_migrations`.

## Bekannte Version-1-Grenzen

- Es gibt genau einen gemeinsamen Ankündigungskanal.
- Keine offene Registrierung.
- Keine privaten Chats, Standortdaten oder Telefonnummern.
- Ankündigungen unterstützen höchstens vier Fotos/Dateien mit je 8 MB; bei
  100 MB Gesamtvolumen je Nutzer. Bei deutlich wachsender Nutzung ist eine Migration von Datenbank-BLOBs zu
  privatem Objektspeicher zu prüfen.
- Profilbearbeitung durch Admins ist als API-Stelle vorgesehen, aber in Version 1 bewusst deaktiviert.
