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
| GET | `/me/attachments?sort=date_desc` | Eigene Cloud-Dateien und 100-MB-Nutzung |
| DELETE | `/me/attachments/{id}` | Eigene Cloud-Datei dauerhaft löschen |

Für die Dateiliste sind `date_desc`, `date_asc`, `size_desc` und `size_asc`
zulässig. Die Nutzung umfasst auch noch keiner Nachricht zugeordnete Uploads.

## Dienstplan

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/duties/upcoming` | Werktage von heute bis einschließlich Tag 14 |
| GET | `/duties/history?date=YYYY-MM-DD` | Letztes Jahr, optional nach exaktem Datum gefiltert |
| POST | `/duties` | Lehrer/Leitung: Diensttag anlegen |
| PATCH | `/duties/{date}` | Lehrer/Leitung: Diensttag oder Ausfall bearbeiten |
| POST | `/duties/closures` | Lehrer/Leitung: einzelnen Ausfalltag oder Zeitraum anlegen |
| POST | `/duties/closures/reset` | Lehrer/Leitung: Ausfallzeitraum aufheben |
| POST | `/duties/{date}/reset` | Lehrer/Leitung: besonderen Tag zurücksetzen |
| GET | `/duties/{date}` | Tagesdetails |
| POST | `/duties/{date}/self` | Selbst eintragen |
| DELETE | `/duties/{date}/self` | Selbst regulär austragen |
| POST | `/duties/{date}/sick` | Krankmelden |
| POST | `/duties/{date}/assignments` | Admin: Person eintragen |
| DELETE | `/duties/{date}/assignments/{assignmentId}` | Admin: Eintragung entfernen |

`date` ist `YYYY-MM-DD`.

Diensttag anlegen:

```json
{
  "date": "2026-09-14",
  "capacity": 5,
  "title": "Sportfest",
  "description": "Treffpunkt ist der Sanitätsraum."
}
```

`capacity` liegt zwischen 1 und 20. `title` und `description` sind optional.
Beim Bearbeiten enthält der Body dieselben Felder plus `is_closed`.

Ausfall oder Ferien:

```json
{
  "start_date": "2026-10-12",
  "end_date": "2026-10-23",
  "name": "Herbstferien",
  "description": "Die Schule bleibt geschlossen."
}
```

Bei einem einzelnen Ausfalltag sind Start- und Enddatum identisch. Wochenenden
werden innerhalb des Zeitraums ausgelassen. Ein Tag mit geplanten Eintragungen
kann erst geschlossen werden, nachdem diese Eintragungen entfernt wurden.

`POST /duties/{date}/reset` entfernt Titel, Beschreibung und Ausfallmarkierung
und stellt einen normalen aktiven Diensttag wieder her. Bestehende
Eintragungen bleiben erhalten. `/duties/closures/reset` erhält
`start_date`/`end_date` und hebt nur Ausfalltage im gewählten Zeitraum auf.

## Ankündigungen

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/announcements` | Neueste Nachrichten |
| POST | `/announcements` | Nachricht senden |
| POST | `/announcements/attachments` | Foto oder Datei vor dem Versand hochladen |
| GET | `/announcements/attachments/{id}` | Anhang authentifiziert öffnen |

Nachrichten werden serverseitig dem aktuellen Nutzer zugeordnet. Eine
Client-Absender-ID wird ignoriert. Der Body kann Text, bis zu vier zuvor
hochgeladene Anhänge oder beides enthalten:

```json
{
  "message": "Bitte beachten",
  "attachment_ids": [17, 18]
}
```

Ein Upload nutzt `multipart/form-data` mit dem Feld `attachment`. Pro Datei
gelten 8 MB. Erlaubt sind JPEG, PNG, WEBP, HEIC/HEIF, PDF, TXT sowie gängige
Word-, Excel- und PowerPoint-Formate. Ein Upload kann nur vom hochladenden
Nutzer derselben Schule einmalig einer Nachricht zugeordnet werden.
Nicht zugeordnete Uploads werden nach einem Tag durch den Wartungsjob entfernt.
Downloads benötigen immer eine gültige Sitzung und werden auf die eigene Schule
begrenzt.

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

Beim Erstellen eines `sanitaeter`- oder `sani_leitung`-Accounts ist zusätzlich
ein nicht in der Zukunft liegendes Datum erforderlich:

```json
{
  "first_name": "Erika",
  "last_name": "Beispiel",
  "username": "erika.b",
  "email": "erika@example.edu",
  "temporary_password": "ein-sicheres-startpasswort",
  "role": "sanitaeter",
  "sanitaeter_since": "2024-08-15"
}
```

`sanitaeter_since` kann später nicht geändert werden. Zulässige Rollen sind
`sanitaeter`, `sani_leitung`, `teacher` und `sekretariat`. Die normale
Rollenänderung ist serverseitig ausschließlich auf `sanitaeter` ↔
`sani_leitung` für bereits bestehende Saniprofile begrenzt.
