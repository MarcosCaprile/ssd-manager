# REST-API

Basis: `/api/v1`

Alle Endpunkte außer Login und Refresh erwarten:

```http
Authorization: Bearer ACCESS_TOKEN
Accept: application/json
Content-Type: application/json
```

Antwortformat:

```json
{ "data": {}, "message": null }
```

Fehlerformat:

```json
{ "error": true, "message": "Verständliche Fehlermeldung" }
```

## Auth

| Methode | Pfad | Zweck |
| --- | --- | --- |
| POST | `/auth/login` | Login mit E-Mail oder Benutzername |
| POST | `/auth/refresh` | Access-Token erneuern |
| POST | `/auth/logout` | Aktuelle Sitzung widerrufen |
| GET | `/auth/session` | Aktuelle Sitzung prüfen |
| POST | `/auth/device-token` | FCM-Token aktualisieren |
| POST | `/auth/password` | Passwort ändern |

Login-Body:

```json
{
  "identifier": "lehrer@example.edu",
  "password": "secret",
  "device_name": "Pixel",
  "platform": "android",
  "device_model": "Google Pixel",
  "app_version": "1.0.0+1",
  "firebase_token": "optional"
}
```

## Eigener Account

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/me` | Eigenes Profil |
| GET | `/me/statistics` | Eigene Dienststatistik |
| GET | `/me/devices` | Aktive Geräte |
| DELETE | `/me/devices/{id}` | Eigenes anderes Gerät abmelden |
| DELETE | `/me/devices` | Alle anderen eigenen Geräte abmelden |

## Dienstplan

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/duties/upcoming` | Heute plus kommende 13 Tage |
| GET | `/duties/history` | Letztes Jahr |
| GET | `/duties/{date}` | Tagesdetails |
| POST | `/duties/{date}/self` | Selbst eintragen |
| DELETE | `/duties/{date}/self` | Selbst regulär austragen |
| POST | `/duties/{date}/sick` | Krankmelden |
| POST | `/duties/{date}/assignments` | Admin: Person eintragen |
| DELETE | `/duties/{date}/assignments/{assignmentId}` | Admin: Eintragung entfernen |

`date` ist `YYYY-MM-DD`.

## Ankündigungen

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/announcements` | Neueste Nachrichten |
| POST | `/announcements` | Nachricht senden |

Nachrichten werden serverseitig dem aktuellen Nutzer zugeordnet. Eine Client-Absender-ID wird ignoriert.

## Nutzerverwaltung

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/users` | Sani-Liste bzw. Admin-Liste |
| POST | `/users` | Account erstellen |
| GET | `/users/{id}` | Profil und Statistik |
| PATCH | `/users/{id}` | Für Version 1 deaktiviert |
| POST | `/users/{id}/deactivate` | Account deaktivieren |
| POST | `/users/{id}/reactivate` | Account reaktivieren |
| POST | `/users/{id}/mark-deletion` | 30-Tage-Löschvormerkung |
| PATCH | `/users/{id}/role` | Rolle ändern |
