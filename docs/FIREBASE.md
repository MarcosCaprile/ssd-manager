# Firebase Cloud Messaging

## Flutter

Die App initialisiert Firebase und lokale Benachrichtigungen defensiv in
`PushService.initializeFirebaseIfConfigured()`. Ohne native Firebase-Dateien
startet die App trotzdem, Push-Tokens bleiben dann `null`.

Benötigte Dateien:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Android und iOS sind in Firebase mit derselben dauerhaft festgelegten
App-Kennung `com.minutmate.ssdmanager` zu registrieren. Eine Firebase-App mit
einer abweichenden Paket- oder Bundle-Kennung ist mit den nativen Builds nicht
kompatibel.

Diese Dateien sind in `.gitignore`, weil sie projektbezogene Konfiguration enthalten.

Android wendet das Google-Services-Gradle-Plugin nur an, wenn
`google-services.json` vorhanden ist. Announcement-Pushes werden als
data-only FCM-Nachrichten empfangen und lokal unter der festen ID `41001` als
Inbox-Benachrichtigung aktualisiert. Bis zu sechs neue Zeilen bleiben in einem
einzigen Notification-Stack; beim Öffnen des Ankündigungsbereichs wird er
gelöscht. Andere Pushes verwenden eigene Benachrichtigungen.

iOS erhält einen normalen APNs-Alert mit `thread-id=ssd-announcements`, damit
das System Nachrichten desselben Chats gruppiert. In beiden Plattformen
öffnet die Payload weiterhin den vorgesehenen App-Bereich. Token-Rotationen
werden nach erfolgreicher Authentifizierung erneut an `/auth/device-token`
gesendet.

## Backend

Das Backend nutzt FCM HTTP v1. Dafür wird ein Firebase Service Account benötigt:

```env
FCM_ENABLED=true
FIREBASE_SERVICE_ACCOUNT=/secure/path/firebase-service-account.json
FIREBASE_PROJECT_ID=your-project-id
```

Das Service-Account-JSON darf nicht im Webroot und nicht im Repository liegen.
Auch die nativen App-Konfigurationsdateien und APNs-/Firebase-Einstellungen
müssen vom Projektinhaber im echten Firebase-/Apple-Konto eingerichtet werden.

## Notification Routing

Die App sendet und empfängt Routing-Daten über `data`:

- `route=announcements`
- `route=duty&date=YYYY-MM-DD`
- `route=profile_devices`

Die konkrete Deep-Link-Navigation ist vorbereitet über diese Payload-Struktur. Bei fehlender Sitzung soll die App zuerst Login anzeigen und danach das Ziel öffnen.

## Auslöser

- Neue Ankündigung: alle anderen aktiven Nutzer
- Freier Platz nach regulärer Austragung: geeignete Sanis
- Krankmeldung: alle anderen aktiven Sanis, Sani-Leitung, Lehreraufsicht und
  Sekretariat; hohe Priorität und verknüpfte Systemankündigung
- Administrative Eintragung: betroffene Person
- Administrative Entfernung: betroffene Person
- 48-Stunden-Erinnerung: Cronjob `backend/cron/run_due_jobs.php`
