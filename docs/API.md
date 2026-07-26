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
  "device_install_id": "64-character-random-installation-id",
  "firebase_token": "optional"
}
```

`device_install_id` ist eine zufällige, pro App-Installation dauerhaft
gespeicherte Kennung. Bei einem erneuten Login derselben Installation ersetzt
die neue Sitzung eine noch aktive alte Sitzung. Clients ohne Kennung bleiben
vorerst kompatibel.

## Eigener Account

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/me` | Eigenes Profil |
| GET | `/me/statistics` | Eigene Dienststatistik |
| GET | `/me/devices` | Aktive Geräte |
| DELETE | `/me/devices/{id}` | Eigenes anderes Gerät abmelden |
| DELETE | `/me/devices` | Alle anderen eigenen Geräte abmelden |
| GET | `/me/attachments?sort=date_desc` | Eigene Cloud-Dateien und 100-MB-Nutzung |
| DELETE | `/me/attachments/{id}` | Inhalt der eigenen Cloud-Datei löschen und Speicher freigeben |

Für die Dateiliste sind `date_desc`, `date_asc`, `size_desc` und `size_asc`
zulässig. Die Nutzung umfasst auch noch keiner Nachricht zugeordnete Uploads.
Bei einem bereits versendeten Anhang bleiben Nachricht und Metadaten erhalten;
die Dateibytes werden entfernt und der Anhang wird als gelöscht markiert.

## Dienstplan

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/duties/upcoming` | Werktage und explizite Wochenend-Events von heute bis einschließlich Tag 14 |
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

`capacity` liegt zwischen 1 und 50. `title` ist beim Anlegen immer erforderlich,
`description` bleibt optional. Explizit benannte Diensttage dürfen auch an
Samstagen und Sonntagen angelegt werden. Beim Bearbeiten enthält der Body
dieselben Felder plus `is_closed`; Wochenend-Events müssen ihren Namen behalten.

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
und stellt an Werktagen einen normalen aktiven Diensttag wieder her. Ein
unbelegtes Wochenend-Event wird beim Zurücksetzen vollständig entfernt; ein
belegtes Wochenend-Event muss zuerst geleert werden. Bestehende Eintragungen an
Werktagen bleiben erhalten. `/duties/closures/reset` erhält
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

Gelöschte versendete Anhänge bleiben in der Nachricht als Metadatensatz mit
`is_deleted: true` erhalten. Ihr Download liefert keinen Dateiinhalt mehr; die
App zeigt stattdessen `Dieser Inhalt wurde gelöscht.` an.

Jede Nachricht enthält `message_type` (`user` oder `system`) und optional
`system_type`. Eine Krankmeldung erzeugt `message_type=system` und
`system_type=duty_sick_reported`; der Text nennt Benutzername, Datum und Anzahl
der noch geplanten Sanis. Diese Nachricht wird serverseitig erzeugt und nicht
als frei wählbarer Client-Absender akzeptiert.

## Nutzerverwaltung

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/users` | Sani-Liste bzw. Admin-Liste |
| POST | `/users` | Account erstellen |
| POST | `/users/bulk/validate` | Manager: bis zu 250 Sani-Aktionen vollständig prüfen |
| POST | `/users/bulk/apply` | Manager: geprüfte Sani-Aktionen transaktional anwenden |
| GET | `/users/{id}` | Profil und Statistik |
| PATCH | `/users/{id}` | Für Version 1 deaktiviert |
| POST | `/users/{id}/deactivate` | Account deaktivieren |
| POST | `/users/{id}/reactivate` | Account reaktivieren |
| POST | `/users/{id}/mark-deletion` | 30-Tage-Löschvormerkung |
| GET | `/users/{id}/data-export` | Strukturierte Datenauskunft (Manager) |
| GET | `/users/{id}/data-export/archive` | ZIP-Datenauskunft inklusive eigener Anhänge (Manager) |
| PATCH | `/users/{id}/role` | Rolle ändern |

Beim Erstellen eines `sanitaeter`- oder `sani_leitung`-Accounts ist zusätzlich
ein gültiges Datum erforderlich. Es darf in der Vergangenheit oder Zukunft
liegen:

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

Bulk-Endpunkte erhalten `{"rows": [...]}`. Jede Zeile enthält `row_number`,
`action`, eine exportierte `id` (außer bei `create`) sowie die
Accountfelder. Zulässige Aktionen sind `create`, `update`, `deactivate`,
`reactivate` und `mark_deletion`. Die Antwort enthält pro Zeile
`valid`/`errors`; `/bulk/apply` speichert nur, wenn alle Zeilen gültig sind.
Bulk ist auf Sani-/Leitungsaccounts derselben Schule begrenzt, kann den eigenen
Account nicht verändern, übernimmt kein exportiertes Passwort und ändert ein
bestehendes `sanitaeter_since` nicht.

Deaktivierte Accounts werden nur Lehreraufsicht und Sani-Leitung in einem
separaten Verwaltungsabschnitt geliefert. Beim Deaktivieren werden alle
Sitzungen sofort widerrufen. Ein Loginversuch erhält den verständlichen Hinweis,
dass der Account deaktiviert ist und eine verantwortliche Person der Schule
kontaktiert werden soll.
