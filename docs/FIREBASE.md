# Firebase Cloud Messaging

## Flutter

Die App initialisiert Firebase defensiv in `PushService.initializeFirebaseIfConfigured()`. Ohne native Firebase-Dateien startet die App trotzdem, Push-Tokens bleiben dann `null`.

Benötigte Dateien:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Diese Dateien sind in `.gitignore`, weil sie projektbezogene Konfiguration enthalten.

## Backend

Das Backend nutzt FCM HTTP v1. Dafür wird ein Firebase Service Account benötigt:

```env
FCM_ENABLED=true
FIREBASE_SERVICE_ACCOUNT=/secure/path/firebase-service-account.json
FIREBASE_PROJECT_ID=your-project-id
```

Das Service-Account-JSON darf nicht im Webroot und nicht im Repository liegen.

## Notification Routing

Die App sendet und empfängt Routing-Daten über `data`:

- `route=announcements`
- `route=duty&date=YYYY-MM-DD`
- `route=profile_devices`

Die konkrete Deep-Link-Navigation ist vorbereitet über diese Payload-Struktur. Bei fehlender Sitzung soll die App zuerst Login anzeigen und danach das Ziel öffnen.

## Auslöser

- Neue Ankündigung: alle anderen aktiven Nutzer
- Freier Platz nach regulärer Austragung: geeignete Sanis
- Krankmeldung: Sanis, Sani-Leitung und Lehreraufsicht, hohe Priorität
- Administrative Eintragung: betroffene Person
- Administrative Entfernung: betroffene Person
- 48-Stunden-Erinnerung: Cronjob `backend/cron/run_due_jobs.php`
